/* dbversion.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef DB_VERSION_H
#define DB_VERSION_H

#include <Foundation/Foundation.h>

static int dbversion = 1;

static NSString *dbschema = @"\
CREATE TABLE files (path TEXT UNIQUE ON CONFLICT IGNORE PRIMARY KEY NOT NULL, \
type TEXT, \
moddate TEXT, \
annotations TEXT, \
icon BLOB); \
\
CREATE INDEX annotations_index ON files(annotations); \
\
\
\
CREATE TABLE cpaths \
(path_id INTEGER PRIMARY KEY NOT NULL, \
path TEXT UNIQUE ON CONFLICT IGNORE NOT NULL); \
\
CREATE TABLE last_cpaths_insert (row_id INTEGER); \
insert into last_cpaths_insert values (0); \
\
CREATE TRIGGER before_cpaths_insert BEFORE INSERT ON cpaths \
BEGIN \
UPDATE last_cpaths_insert SET row_id = (SELECT path_id FROM cpaths where path = new.path); \
UPDATE last_word_loc_insert SET row_id = 0; \
END; \
\
CREATE TRIGGER after_cpaths_insert AFTER INSERT ON cpaths \
BEGIN \
UPDATE last_cpaths_insert SET row_id = last_insert_rowid(); \
END; \
\
CREATE TRIGGER cpaths_delete BEFORE DELETE ON cpaths \
BEGIN \
DELETE FROM word_locations WHERE wloc_path_id = old.path_id; \
END; \
\
\
\
CREATE TABLE words \
(word_id INTEGER PRIMARY KEY NOT NULL, \
word TEXT UNIQUE ON CONFLICT IGNORE NOT NULL); \
\
CREATE TRIGGER before_words_insert BEFORE INSERT ON words \
BEGIN \
INSERT OR IGNORE INTO word_locations(wloc_word_id, wloc_path_id, wloc_prev_id) \
VALUES((SELECT word_id FROM words where word = new.word), \
(SELECT row_id FROM last_cpaths_insert), \
(SELECT row_id FROM last_word_loc_insert)); \
END; \
\
CREATE TRIGGER after_words_insert AFTER INSERT ON words \
BEGIN \
INSERT INTO word_locations(wloc_path_id, wloc_word_id, wloc_prev_id) \
VALUES((SELECT row_id FROM last_cpaths_insert), \
last_insert_rowid(), \
(SELECT row_id FROM last_word_loc_insert)); \
END; \
\
CREATE TRIGGER words_delete BEFORE DELETE ON words \
BEGIN \
DELETE FROM word_locations WHERE wloc_word_id = old.word_id; \
END; \
\
\
\
CREATE TABLE word_locations \
(wloc_id INTEGER PRIMARY KEY NOT NULL, \
wloc_path_id INTEGER REFERENCES cpaths(path_id), \
wloc_word_id INTEGER NOT NULL REFERENCES words(word_id), \
wloc_prev_id INTEGER REFERENCES word_locations(wloc_id)); \
\
CREATE INDEX wloc_word_index ON word_locations(wloc_word_id); \
CREATE INDEX wloc_prev_index ON word_locations(wloc_prev_id); \
\
CREATE TABLE last_word_loc_insert (row_id INTEGER); \
insert into last_word_loc_insert values (0); \
\
CREATE TRIGGER word_loc_insert AFTER INSERT ON word_locations \
BEGIN \
UPDATE last_word_loc_insert SET row_id = last_insert_rowid(); \
END; \
";



/*
SQLite automatically creates an index for every UNIQUE column, 
and for every PRIMARY KEY column.


CREATE TABLE cpaths 
(path_id INTEGER PRIMARY KEY NOT NULL, 
path TEXT UNIQUE ON CONFLICT IGNORE NOT NULL); 

CREATE TABLE last_cpaths_insert (row_id INTEGER); 
insert into last_cpaths_insert values (0); 

CREATE TRIGGER before_cpaths_insert BEFORE INSERT ON cpaths 
BEGIN 
UPDATE last_cpaths_insert SET row_id = (SELECT path_id FROM cpaths where path = new.path); 
UPDATE last_word_loc_insert SET row_id = 0;
END; 

CREATE TRIGGER after_cpaths_insert AFTER INSERT ON cpaths 
BEGIN 
UPDATE last_cpaths_insert SET row_id = last_insert_rowid(); 
END; 

CREATE TRIGGER cpaths_delete BEFORE DELETE ON cpaths 
BEGIN 
DELETE FROM word_locations WHERE wloc_path_id = old.path_id; 
END; 


CREATE TABLE words 
(word_id INTEGER PRIMARY KEY NOT NULL, 
word TEXT UNIQUE ON CONFLICT IGNORE NOT NULL); 

CREATE TRIGGER before_words_insert BEFORE INSERT ON words
BEGIN
INSERT OR IGNORE INTO word_locations(wloc_word_id, wloc_path_id, wloc_prev_id)
VALUES((SELECT word_id FROM words where word = new.word),
(SELECT row_id FROM last_cpaths_insert),
(SELECT row_id FROM last_word_loc_insert));
END;

CREATE TRIGGER after_words_insert AFTER INSERT ON words 
BEGIN 
INSERT INTO word_locations(wloc_path_id, wloc_word_id, wloc_prev_id) 
VALUES((SELECT row_id FROM last_cpaths_insert), 
last_insert_rowid(), 
(SELECT row_id FROM last_word_loc_insert)); 
END; 

CREATE TRIGGER words_delete BEFORE DELETE ON words 
BEGIN 
DELETE FROM word_locations WHERE wloc_word_id = old.word_id; 
END; 


CREATE TABLE word_locations 
(wloc_id INTEGER PRIMARY KEY NOT NULL, 
wloc_path_id INTEGER REFERENCES cpaths(path_id), 
wloc_word_id INTEGER NOT NULL REFERENCES words(word_id), 
wloc_prev_id INTEGER REFERENCES word_locations(wloc_id)); 

CREATE INDEX wloc_word_index ON word_locations(wloc_word_id);
CREATE INDEX wloc_prev_index ON word_locations(wloc_prev_id);

CREATE TABLE last_word_loc_insert (row_id INTEGER); 
insert into last_word_loc_insert values (0); 

CREATE TRIGGER word_loc_insert AFTER INSERT ON word_locations 
BEGIN 
UPDATE last_word_loc_insert SET row_id = last_insert_rowid(); 
END; 



  // SOLO UNA 
  SELECT 
    cpaths.path, 
    cpaths.path_id, 
    count(*) AS relevance
  FROM 
    cpaths, 
    word_locations
  WHERE 
      cpaths.path_id=word_locations.wloc_path_id 
    AND
      word_locations.wloc_word_id = (SELECT word_id FROM words WHERE word GLOB 'apple*')
  GROUP BY cpaths.path_id
  ORDER BY relevance, cpaths.path;
  


  // CI SONO TUTTE E DUE
  SELECT 
    cpaths.path, 
    cpaths.path_id, 
    count(*) AS relevance 
  FROM 
    cpaths, 
    word_locations AS wloc0,
    word_locations AS wloc1 
  WHERE 
      cpaths.path_id=wloc0.wloc_path_id 
    AND
      wloc0.wloc_word_id = (SELECT word_id FROM words WHERE word GLOB 'know*')
    AND 
      cpaths.path_id=wloc1.wloc_path_id 
    AND
      wloc1.wloc_word_id = (SELECT word_id FROM words WHERE word GLOB 'print*')
  GROUP BY cpaths.path_id
  ORDER BY relevance, cpaths.path;



  // FRASE ESATTA
  SELECT 
    cpaths.path, 
    cpaths.path_id, 
    count(*) AS relevance 
  FROM 
    cpaths, 
    word_locations AS wloc0,
    word_locations AS wloc1 
  WHERE 
      cpaths.path_id=wloc0.wloc_path_id 
    AND
      wloc0.wloc_word_id = (SELECT word_id FROM words WHERE word = 'known')
    AND 
      wloc1.wloc_word_id = (SELECT word_id FROM words WHERE word = 'printers')
    AND 
      wloc1.wloc_prev_id = wloc0.wloc_id
  GROUP BY cpaths.path_id
  ORDER BY relevance, cpaths.path;


DROP TABLE last_word_loc_insert;
DROP TABLE word_locations;
DROP TABLE last_words_insert;
DROP TABLE words;
DROP TABLE last_cpaths_insert;
DROP TABLE cpaths;

*/

#endif // DB_VERSION_H
