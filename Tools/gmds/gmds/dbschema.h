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









