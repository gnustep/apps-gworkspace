
static NSString *db_version = @"v4";


static NSString *db_schema = @"\
\
CREATE TABLE paths \
(id INTEGER PRIMARY KEY AUTOINCREMENT, \
path TEXT UNIQUE ON CONFLICT IGNORE, \
words_count INTEGER, \
moddate REAL, \
is_directory INTEGER); \
\
CREATE TABLE words \
(id INTEGER PRIMARY KEY AUTOINCREMENT, \
word TEXT UNIQUE ON CONFLICT IGNORE); \
\
CREATE TABLE postings \
(word_id INTEGER REFERENCES words(id), \
path_id INTEGER REFERENCES paths(id), \
word_count INTEGER); \
\
CREATE INDEX postings_wid_index ON postings(word_id); \
CREATE INDEX postings_pid_index ON postings(path_id); \
\
\
CREATE TABLE attributes \
(path_id INTEGER REFERENCES paths(id), \
key TEXT, \
attribute TEXT); \
\
CREATE INDEX attributes_path_index ON attributes(path_id); \
CREATE INDEX attributes_key_attr_index ON attributes(key, attribute); \
CREATE INDEX attributes_attr_index ON attributes(attribute); \
\
\
CREATE TABLE updated_paths \
(id INTEGER UNIQUE ON CONFLICT REPLACE, \
path TEXT UNIQUE ON CONFLICT REPLACE, \
words_count INTEGER, \
moddate REAL, \
is_directory INTEGER, \
timestamp REAL); \
\
CREATE INDEX updated_paths_index ON updated_paths(timestamp); \
\
CREATE TABLE removed_paths \
(path TEXT UNIQUE ON CONFLICT REPLACE); \
\
\
CREATE TRIGGER updated_paths_trigger AFTER UPDATE ON paths \
WHEN (checkUpdating() != 0) \
  BEGIN \
    INSERT INTO updated_paths (id, path, words_count, moddate, is_directory, timestamp) \
    VALUES (new.id, new.path, new.words_count, new.moddate, new.is_directory, timeStamp()); \
  END; \
\
CREATE TRIGGER deleted_paths_trigger AFTER DELETE ON paths \
WHEN (checkUpdating() != 0) \
  BEGIN \
    DELETE FROM updated_paths WHERE id = old.id; \
    INSERT INTO removed_paths (path) \
    VALUES (old.path); \
  END; \
";

static NSString *db_schema_tmp = @"\
CREATE TEMP TABLE removed_id \
(id INTEGER PRIMARY KEY); \
\
\
CREATE TEMP TABLE renamed_paths \
(id INTEGER PRIMARY KEY, \
path TEXT, \
base TEXT, \
oldbase TEXT); \
\
CREATE TEMP TABLE renamed_paths_base \
(base TEXT, \
oldbase TEXT); \
\
CREATE TEMP TRIGGER renamed_paths_trigger AFTER INSERT ON renamed_paths \
BEGIN \
  INSERT INTO removed_paths (path) VALUES (new.path); \
  UPDATE paths \
  SET path = pathMoved(new.oldbase, new.base, new.path) \
  WHERE id = new.id; \
END; \
";




/* for ddbd when/if it will be sqlite-based */
static NSString *user_db_schema = @"\
\
CREATE TABLE user_paths \
(id INTEGER PRIMARY KEY AUTOINCREMENT, \
path TEXT UNIQUE ON CONFLICT IGNORE, \
moddate REAL, \
md_moddate REAL, \
is_directory INTEGER); \
\
CREATE INDEX user_paths_directory_index ON user_paths(path, is_directory); \
\
CREATE TABLE user_attributes \
(path_id INTEGER, \
key TEXT, \
attribute BLOB); \
\
CREATE INDEX attributes_path_index ON user_attributes(path_id, key); \
CREATE INDEX attributes_key_index ON user_attributes(key); \
\
CREATE TRIGGER user_attributes_trigger BEFORE INSERT ON user_attributes \
BEGIN \
  DELETE FROM user_attributes \
  WHERE path_id = new.path_id \
  AND key = new.key; \
END; \
";

static NSString *user_db_schema_tmp = @"\
CREATE TEMP TABLE user_paths_removed_id \
(id INTEGER PRIMARY KEY); \
\
\
CREATE TEMP TABLE user_renamed_paths \
(id INTEGER PRIMARY KEY, \
path TEXT, \
base TEXT, \
oldbase TEXT); \
\
CREATE TEMP TABLE user_renamed_paths_base \
(base TEXT, \
oldbase TEXT); \
\
CREATE TEMP TRIGGER user_renamed_paths_trigger AFTER INSERT ON user_renamed_paths \
BEGIN \
  UPDATE user_paths \
  SET path = pathMoved(new.oldbase, new.base, new.path) \
  WHERE id = new.id; \
END; \
\
\
CREATE TEMP TABLE user_copied_paths \
(src_id PRIMARY KEY, \
srcpath TEXT, \
dstpath TEXT, \
srcbase TEXT, \
dstbase TEXT, \
moddate REAL, \
md_moddate REAL, \
is_directory INTEGER); \
\
CREATE TEMP TABLE user_copied_paths_base \
(srcbase TEXT, \
dstbase TEXT); \
\
CREATE TEMP TRIGGER user_copied_paths_trigger_1 AFTER INSERT ON user_copied_paths \
BEGIN \
  UPDATE user_copied_paths \
  SET \
    dstpath = pathMoved(new.srcbase, new.dstbase, new.srcpath), \
    moddate = timeStamp(), \
    md_moddate = timeStamp() \
  WHERE src_id = new.src_id; \
END; \
\
CREATE TEMP TRIGGER user_copied_paths_trigger_2 AFTER UPDATE ON user_copied_paths \
BEGIN \
  INSERT INTO user_paths (path, moddate, md_moddate, is_directory) \
    VALUES (new.dstpath, new.moddate, new.md_moddate, new.is_directory); \
\
  INSERT INTO user_attributes (path_id, key, attribute) \
    SELECT \
      upaths.id, \
      user_attributes.key, \
      user_attributes.attribute \
    FROM \
      (SELECT id FROM user_paths WHERE path = new.dstpath) AS upaths, \
      user_attributes \
    WHERE \
      user_attributes.path_id = new.src_id; \
END; \
";
