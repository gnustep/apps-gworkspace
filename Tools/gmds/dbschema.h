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
score REAL); \
\
CREATE INDEX postings_wid_index ON postings(word_id); \
CREATE INDEX postings_pid_index ON postings(path_id, word_id); \
\
\
CREATE TABLE attributes \
(path_id INTEGER REFERENCES paths(id), \
key TEXT, \
attribute TEXT); \
\
CREATE INDEX attributes_path_index ON attributes(path_id); \
CREATE INDEX attributes_key_index ON attributes(key); \
CREATE INDEX attributes_attr_index ON attributes(attribute); \
\
\
\
CREATE TABLE removed_id \
(id INTEGER PRIMARY KEY); \
\
\
CREATE TABLE renamed_paths \
(id INTEGER PRIMARY KEY, \
path TEXT, \
base TEXT, \
oldbase TEXT); \
\
CREATE TABLE renamed_paths_base \
(base TEXT, \
oldbase TEXT); \
\
CREATE TRIGGER renamed_paths_trigger AFTER INSERT ON renamed_paths \
BEGIN \
  UPDATE paths \
  SET path = pathMoved(new.oldbase, new.base, new.path) \
  WHERE id = new.id; \
END; \
";


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
