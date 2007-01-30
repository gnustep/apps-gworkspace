/* Copyright (C) 2005 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307 USA.  */

#ifndef	_LINUX_INOTIFY_H
#define	_LINUX_INOTIFY_H

#include <linux/types.h>

/* Structure describing an inotify event.  */
struct inotify_event {
	__s32		wd;		/* watch descriptor */
	__u32		mask;		/* watch mask */
	__u32		cookie;		/* cookie to synchronize two events */
	__u32		len;		/* length (including nulls) of name */
	char		name[0];	/* stub for possible name */
};

/* Supported events suitable for MASK parameter of INOTIFY_ADD_WATCH.  */
#define IN_ACCESS	 0x00000001	/* File was accessed.  */
#define IN_MODIFY	 0x00000002	/* File was modified.  */
#define IN_ATTRIB	 0x00000004	/* Metadata changed.  */
#define IN_CLOSE_WRITE	 0x00000008	/* Writtable file was closed.  */
#define IN_CLOSE_NOWRITE 0x00000010	/* Unwrittable file closed.  */
#define IN_CLOSE	 (IN_CLOSE_WRITE | IN_CLOSE_NOWRITE) /* Close.  */
#define IN_OPEN		 0x00000020	/* File was opened.  */
#define IN_MOVED_FROM	 0x00000040	/* File was moved from X.  */
#define IN_MOVED_TO      0x00000080	/* File was moved to Y.  */
#define IN_MOVE		 (IN_MOVED_FROM | IN_MOVED_TO) /* Moves.  */
#define IN_CREATE	 0x00000100	/* Subfile was created.  */
#define IN_DELETE	 0x00000200	/* Subfile was deleted.  */
#define IN_DELETE_SELF	 0x00000400	/* Self was deleted.  */
#define IN_MOVE_SELF	 0x00000800	/* Self was moved.  */

/* Events sent by the kernel.  */
#define IN_UNMOUNT	 0x00002000	/* Backing fs was unmounted.  */
#define IN_Q_OVERFLOW	 0x00004000	/* Event queued overflowed.  */
#define IN_IGNORED	 0x00008000	/* File was ignored.  */

/* Special flags.  */
#define IN_ISDIR	 0x40000000	/* Event occurred against dir.  */
#define IN_ONESHOT	 0x80000000	/* Only send event once.  */

/* All events which a program can wait on.  */
#define IN_ALL_EVENTS	 (IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE  \
			  | IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM	      \
			  | IN_MOVED_TO | IN_CREATE | IN_DELETE		      \
			  | IN_DELETE_SELF | IN_MOVE_SELF)


#ifdef __KERNEL__

#include <linux/dcache.h>
#include <linux/fs.h>
#include <linux/config.h>

#ifdef CONFIG_INOTIFY

extern void inotify_inode_queue_event(struct inode *, __u32, __u32,
				      const char *);
extern void inotify_dentry_parent_queue_event(struct dentry *, __u32, __u32,
					      const char *);
extern void inotify_unmount_inodes(struct list_head *);
extern void inotify_inode_is_dead(struct inode *);
extern u32 inotify_get_cookie(void);

#else

static inline void inotify_inode_queue_event(struct inode *inode,
					     __u32 mask, __u32 cookie,
					     const char *filename)
{
}

static inline void inotify_dentry_parent_queue_event(struct dentry *dentry,
						     __u32 mask, __u32 cookie,
						     const char *filename)
{
}

static inline void inotify_unmount_inodes(struct list_head *list)
{
}

static inline void inotify_inode_is_dead(struct inode *inode)
{
}

static inline u32 inotify_get_cookie(void)
{
	return 0;
}

#endif	/* CONFIG_INOTIFY */

#endif	/* __KERNEL __ */

#endif /* _LINUX_INOTIFY_H */
