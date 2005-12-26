/* fswatcher.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2005
 * 
 * Partially taken from the "Changedfiles" system.
 * Copright (C)2001 Michael L. Welles <mike@bangstate.com>
 * Released under the terms of the GNU General Public License
 *
 * This file is part of the GNUstep GWorkspace application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <linux/slab.h> 
#include <linux/kernel.h> 
#include <linux/module.h> 
#include <sys/syscall.h> 
#include <linux/fs.h> 
#include <linux/sched.h> 
#include <asm/segment.h> 
#include <asm/uaccess.h> 
#include <linux/string.h> 
#include <linux/types.h> 
#include <linux/smp_lock.h>  
#include <asm/segment.h>
#include <linux/version.h> 
#include <linux/locks.h>  

#define FSWATCHER_OPENW 0
#define FSWATCHER_RMDIR 2
#define FSWATCHER_MKDIR 3
#define FSWATCHER_UNLINK 6
#define FSWATCHER_CREATE 7
#define FSWATCHER_RENAME 9 

#define SEPARATOR " ]]]----->> "

#ifndef MIN
  #define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

#define BUF_SIZE  512
#define MAX_PATH  512

/* device info for the fswatcher device */ 
static int fswatcher_major = 40;

/* address of original syscalls sysc*/
int (*original_open)(const char *filename, int flags, int mode); 
int (*original_rmdir)(const char *pathname); 
int (*original_mkdir)(const char *pathname, int mode); 
int (*original_unlink)(const char *pathname); 
int (*original_create)(const char *pathname, int mode);
int (*original_rename)(const char *oldname, const char *newname); 

int (*getcwd)(char *buf, unsigned long size);

char fswatcher_buffer[BUF_SIZE][MAX_PATH];
int fsw_buffer_head = 0;
int fsw_buffer_tail = 0;

char *read_buf; 

spinlock_t fswatcher_lock = SPIN_LOCK_UNLOCKED; 
unsigned long lock_flags;

int my_strlen (const char *mstr) 
{ 
  char *c; 
  int i = 0; 
  
  c = (char *)mstr; 
  
  while (*c != '\0') { 
	  c++; 
	  i++; 
	}
  
  return i; 
}

int fswatcher_get_from_buffer(char *c, int size) 
{
  spin_lock_irqsave(&fswatcher_lock, lock_flags); 
  *c = '\0'; 

  if (fsw_buffer_head == fsw_buffer_tail) { 
    spin_unlock_irqrestore(&fswatcher_lock, lock_flags); 
    return 0;
  }
    
  strncpy(c, (char *)fswatcher_buffer[fsw_buffer_head], size);
  memset(fswatcher_buffer[fsw_buffer_head], 0, MAX_PATH);
  fsw_buffer_head++;
   
  if (fsw_buffer_head == BUF_SIZE) {
    fsw_buffer_head = 0;
  }
  
  spin_unlock_irqrestore(&fswatcher_lock, lock_flags); 
  
  return 0;
}

void fswatcher_malloc_and_zero_buffer() 
{ 
  int i; 
  
  for (i = 0; i < BUF_SIZE; i++) { 
    memset(fswatcher_buffer[i], 0, MAX_PATH); 
  }
}
	
int fswatcher_put_to_buffer(char *c)
{
  spin_lock_irqsave(&fswatcher_lock, lock_flags); 
  
  if ((fsw_buffer_tail + 1) == fsw_buffer_head
	      || (((fsw_buffer_tail + 1) == BUF_SIZE) && (fsw_buffer_head == 0))) { 
    fsw_buffer_head++;
    
    if (fsw_buffer_head == BUF_SIZE) { 
		  fsw_buffer_head = 0; 
		}
    
    /*signal fswatcher_buffer overrun*/
    strncpy((char *)fswatcher_buffer[fsw_buffer_head], "!", 2);
  }
  
  if (!fswatcher_buffer[fsw_buffer_tail]) { 
    spin_unlock_irqrestore(&fswatcher_lock, lock_flags); 
    return -ENOMEM; 
  }
  
  strncpy((char *)fswatcher_buffer[fsw_buffer_tail], c, MAX_PATH); 
  fsw_buffer_tail++;

  if (fsw_buffer_tail == BUF_SIZE) {
    fsw_buffer_tail = 0;
  }
  
  spin_unlock_irqrestore(&fswatcher_lock, lock_flags);
  
  return 1;
}

void fswatcher_log_filename(const char *oldname, const char *newname, const int operation) 
{ 
  mm_segment_t oldfs;
  char msg[MAX_PATH * 2 + 20]; 
  char fulloldname[MAX_PATH]; 
  char fullnewname[MAX_PATH]; 
  long len = 0; 

  fulloldname[0] = '\0'; 
  fullnewname[0] = '\0'; 
  msg[0] = '\0';
  
  /* basename file names, fill path if neccessary */ 
  if (*oldname == '/') { 
    strncpy(fulloldname, oldname, MAX_PATH); 
  } else { 
    oldfs = get_fs(); 
    set_fs(KERNEL_DS);
    len = getcwd(fulloldname, MAX_PATH);
    set_fs(oldfs);
    
    if (len <  0) { 
	    printk("fswatcher: getcwd returned an error (%ld)\n", len); 
	    return; 
	  }

    if ((my_strlen(fulloldname) + my_strlen(oldname)) >= MAX_PATH) { 
	    len = (my_strlen(fulloldname) + my_strlen(oldname)); 
	    printk("fswatcher: Full filename too long! %d bytes. Max: %d", (int)len, MAX_PATH); 
	    return; 
	  }

    strcat(fulloldname, "/"); 
    strcat(fulloldname, oldname); 
  }

  if (newname != NULL) { 
    if (*newname == '/') { 
	    strncpy(fullnewname, newname, MAX_PATH); 
	  } else { 
	    oldfs = get_fs(); 
      set_fs(KERNEL_DS);
	    len = getcwd(fullnewname, MAX_PATH); 
	    set_fs(oldfs);
	    
      if (len < 0) { 
	      printk("fswatcher: getcwd return an error (%ld)", len); 
	      return; 
	    }
	  
	    if ((my_strlen(fullnewname) + my_strlen(newname)) >= MAX_PATH) { 
	      len = (my_strlen(fulloldname) + my_strlen(oldname)); 
	      printk("fswatcher: Full filename too long! %d bytes. Max: %d", (int)len, MAX_PATH); 
	      return; 
	    }

	    strcat(fullnewname, "/"); 
	    strcat(fullnewname, newname); 
	  }
  }
    
  switch (operation) {
	  case FSWATCHER_OPENW:
	  case FSWATCHER_RMDIR: 
	  case FSWATCHER_MKDIR: 
	  case FSWATCHER_UNLINK: 
	  case FSWATCHER_CREATE: 
      sprintf(msg, "%d ", operation);
	    strcat(msg, fulloldname); 
	    break; 

	  case FSWATCHER_RENAME: 
      sprintf(msg, "%d ", operation);  
	    strcat(msg, fulloldname); 
	    strcat(msg, SEPARATOR); 
	    strcat(msg, fullnewname); 
	    break; 

	  default: 
	    msg[0] = '\0'; 
	}

  if (msg[0] != '\0') { 
    fswatcher_put_to_buffer(msg); 
  }
}

int fswatcher_rename(const char *oldname, const char *newname) 
{ 
  int ret = original_rename(oldname, newname); 

  if (ret >= 0) { 
    fswatcher_log_filename(oldname, newname, FSWATCHER_RENAME); 
  }
  
  return ret; 
}
    
int fswatcher_open(const char *filename, int flags, int mode)
{
  int ret = original_open(filename, flags, mode); 
  
  if (ret >= 0 && (flags & O_WRONLY || flags & O_RDWR)) { 
    fswatcher_log_filename(filename, NULL, FSWATCHER_OPENW); 
	}

  return ret; 
}

extern int fswatcher_rmdir(const char *pathname)
{ 
  int ret = original_rmdir(pathname); 
  
  if (ret >= 0) { 
    fswatcher_log_filename(pathname, NULL, FSWATCHER_RMDIR); 
  }
  
  return ret; 
}

extern int fswatcher_mkdir(const char *pathname, int mode)
{
  int ret = original_mkdir(pathname, mode); 
  
  if (ret >= 0) { 
    fswatcher_log_filename(pathname, NULL, FSWATCHER_MKDIR);
	}
  
  return ret; 
}

extern int fswatcher_unlink(const char *pathname)
{ 
  int ret = original_unlink(pathname); 
  
  if (ret >= 0) { 
    fswatcher_log_filename(pathname, NULL, FSWATCHER_UNLINK); 
	}
  
  return ret; 
}


extern int fswatcher_create(const char *pathname, int mode)
{ 
  int ret = original_create(pathname, mode);
   
  if (ret >= 0) {
    fswatcher_log_filename(pathname, NULL, FSWATCHER_CREATE); 
	}
  
  return ret; 
}

int fswatcher_open_dev(struct inode *in, struct file *fi)
{ 
  MOD_INC_USE_COUNT;
  return 0; 
}

int fswatcher_close_dev(struct inode *in, struct file *fi)
{
  MOD_DEC_USE_COUNT; 
  return 0; 
}

ssize_t fswatcher_read_dev(struct file *filep, char *buf, 
                                          size_t count, loff_t *f_pos)
{ 
  int len; 
  int mycount; 

  if (count > MAX_PATH) { 
    mycount = MAX_PATH; 
  } else { 
    mycount = count; 
  }

  read_buf = kmalloc(mycount, GFP_KERNEL); 

  if (!read_buf) { 
    return -ENOMEM; 
  }
  
  memset(read_buf, 0, mycount); 
  fswatcher_get_from_buffer(read_buf, mycount);
  len = my_strlen(read_buf); 
  
  if (len == 0) { 
    kfree(read_buf); 
    return 0; 
  }

   /* include the \0 */ 
  len++; 
  
  if (copy_to_user(buf, read_buf, mycount)) { 
    printk("fswatcher: copy_to_user failed\n"); 
    kfree(read_buf);
    return -EFAULT; 
  }

  kfree(read_buf);
  
  return len; 
}

static struct file_operations fswatcher_fop = { 
  .read = fswatcher_read_dev,
  .open = fswatcher_open_dev,
  .release = fswatcher_close_dev
};
  
int init_module()
{
  extern long sys_call_table[]; 
  
  printk("fswatcher: init\n"); 
  
  original_open = (int (*)(const char *, int, int))(sys_call_table[__NR_open]); 
  original_rmdir = (int (*)(const char *))(sys_call_table[__NR_rmdir]); 
  original_mkdir = (int (*)(const char *, int))(sys_call_table[__NR_mkdir]); 
  original_unlink = (int (*)(const char *))(sys_call_table[__NR_unlink]); 
  original_rename = (int (*)(const char *, const char *))(sys_call_table[__NR_rename]);

  sys_call_table[__NR_open] = (unsigned long)fswatcher_open; 
  sys_call_table[__NR_rmdir] = (unsigned long)fswatcher_rmdir;
  sys_call_table[__NR_mkdir] = (unsigned long)fswatcher_mkdir; 
  sys_call_table[__NR_unlink] = (unsigned long)fswatcher_unlink; 
  sys_call_table[__NR_rename] = (unsigned long)fswatcher_rename; 

  getcwd = (int (*)(char *, unsigned long))(sys_call_table[__NR_getcwd]);

  fswatcher_malloc_and_zero_buffer(); 

  if (register_chrdev(fswatcher_major, "fswatcher", &fswatcher_fop)) { 
    return -EIO; 
	}
  
  return 0; 
}

void cleanup_module()
{ 
  extern long sys_call_table[]; 
  
  spin_lock_irqsave(&fswatcher_lock, lock_flags); 
  
  printk("fswatcher: unloading -- resetting symbol table\n"); 
  
  sys_call_table[__NR_open] = (unsigned long)original_open; 
  sys_call_table[__NR_rmdir] = (unsigned long)original_rmdir; 
  sys_call_table[__NR_mkdir] = (unsigned long)original_mkdir; 
  sys_call_table[__NR_unlink] = (unsigned long)original_unlink; 
  sys_call_table[__NR_rename] = (unsigned long)original_rename;

  spin_unlock_irqrestore( &fswatcher_lock, lock_flags); 
  
  unregister_chrdev(fswatcher_major, "fswatcher"); 
}

MODULE_AUTHOR("Enrico Sersale <enrico@imago.ro>");
MODULE_DESCRIPTION("reports file operations to /dev/fswatcher");
MODULE_LICENSE("GPL");
