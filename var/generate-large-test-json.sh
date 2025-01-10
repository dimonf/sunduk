#!/usr/bin/env zsh

ROOT_DIR="/share/slow/lib/sunduk"
COUNT=$1
TYPE=${2:-json} # options: json|sqlite
SQLITE_DB=mock.sqlite3
SQLITE_TAGS_PER_FILE=5
SQLITE_TAGS=(alpha bravo giraffe graphene bizzar tripple photo Mars Argentina)
SQLITE_VALUES_NO=1000
sql_fl=

usage () {
  cat <<END
  $(basename $0) -n N

  Options:
   -n       number of objects in output JSON

END
}

_mock_json_object() {
cat <<END
  {
     "file_path":"",
     "created":"YYYY-MM-DD",
     "modified": "YYYY-MM-DD",
     "checksum": "351601d354601ae196c5872969b238cf",
     "origin": "magnet:?xt=urn:btih:9ed97b5a640dd8bc37291d572000dbe4f6953b8a&dn=Astronaut-K%20%282014%29.avi&tr=http%3A%2F%2Fbt2.t-ru.org%2Fann&tr=http%a4%u3%2Frezoombvr.local%2Fannounce",
     "tags":
        {
          "company": "family",
          "p.John": "",
          "p.Lisa": ""
        }
   }
END
}

_init_sqlite_db() {
  sqlite3 $SQLITE_DB <<(echo "
  CREATE TABLE tag (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
  );
   CREATE TABLE file (
     id INTEGER PRIMARY KEY,
     directory TEXT NOT NULL,
     name TEXT NOT NULL,
     fingerprint TEXT NOT NULL,
     mod_time DATETIME NOT NULL,
     create_time DATETIME NOT NULL,
     size INTEGER NOT NULL,
     is_dir BOOLEAN NOT NULL,
     CONSTRAINT con_file_path UNIQUE (directory, name)
   );
   CREATE TABLE value (
     id INTEGER PRIMARY KEY,
     name TEXT NOT NULL,
     CONSTRAINT con_value_name UNIQUE (name)
   );
   CREATE TABLE file_tag (
     file_id INTEGER NOT NULL,
     tag_id INTEGER NOT NULL,
     value_id INTEGER NOT NULL,
     PRIMARY KEY (file_id, tag_id, value_id),
     FOREIGN KEY (file_id) REFERENCES file(id),
     FOREIGN KEY (tag_id) REFERENCES tag(id),
     FOREIGN KEY (value_id) REFERENCES value(id)
   );
   CREATE INDEX idx_file_tag_file_id
   ON file_tag(file_id);
   CREATE INDEX idx_file_tag_tag_id
   ON file_tag(tag_id);
   CREATE INDEX idx_file_tag_value_id
   ON file_tag(value_id);
   ")

   #add records in tag and values tables
   for (( c=1; c<=$SQLITE_VALUES_NO; c++ )); do
     printf >> $sql_fl "
     INSERT INTO value(id,name) 
     VALUES (
       $c,
       random()
      );
      "
    done

    for  (( c=1; c<=${#SQLITE_TAGS[@]}; c++ )); do
      printf >> $sql_fl "
        INSERT INTO tag(id,name) 
        VALUES (
          $c,
          '${SQLITE_TAGS[$c]}'
          );
        "
    done
    echo "$SQLITE_VALUES_NO values added"
    echo "${#SQLITE_TAGS[@]} tags added"
}

_mock_sqlite_record() {
  if [ ! -f  $SQLITE_DB ]; then
    _init_sqlite_db
  fi
  printf >> $sql_fl "
  INSERT INTO file (id, directory, name, fingerprint,mod_time,create_time,size,is_dir)
  VALUES (
     $1,
     '$ROOT_DIR',
     'dump_name_$1.avi',
     '84a2bdf283cfe901d45771a5e3ca053b',
     '20240101T4415',
     '20240101T4415',
     34244223,
     0);
  "
  for (( i=1; i<=$SQLITE_TAGS_PER_FILE; i++ )); do
    RND_T=$(( 1 + $RANDOM % ${#SQLITE_TAGS[@]} ))
    RND_V=$(( 1 + $RANDOM % $SQLITE_VALUES_NO ))
    printf >> $sql_fl "
      INSERT INTO file_tag (file_id, tag_id, value_id)
      VALUES (
        $1,
        $RND_T,
        $RND_V
      );
    "
  done
}

if [ ${#@} -lt 1 ]; then
  exit
fi

if [ $TYPE = 'sqlite' ]; then
  [ -z $sql_fl ] && sql_fl=`mktemp`
  echo "$sql_fl"
  printf >> $sql_fl "BEGIN TRANSACTION;\n"

  for (( fc=1; fc<=$COUNT; fc++ )); do
    _mock_sqlite_record $fc
  done
  printf >> $sql_fl "COMMIT TRANSACTION;\n"

  echo "finish creating data file $sql_fl"
  sqlite3 $SQLITE_DB <$sql_fl
elif [ $TYPE = 'json' ]; then
  for (( fc=1; fc<=$COUNT; fc++ )); do
    _mock_json_object
  done
fi
