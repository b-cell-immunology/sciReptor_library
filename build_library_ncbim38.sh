export CURR_DATE=$( date --iso-8601 )
export library="library_ncbi_m38"

# set up library schemes
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb -e "CREATE SCHEMA IF NOT EXISTS ${library};"
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${library}  < igdb_library.sql

# retrieve mouse
# memorize output folder.
cd VDJ_segments

echo "[OK] Setting up database for NCBI m38 mouse VDJ."
./build_VDJ_db.pl -mysql_group mysql_igdb -lu segments_ncbim38_mouse_2015-05-14.tsv -sp mouse -fa_dir data_ncbim38_mouse_2015-05-14 -lib_scheme ${library} -opt_file ../igdata/optional_file/mouse_ncbim38_gl.aux -log -parse

for file in data_ncbim38_mouse_2015-05-14/mouse*.n*; 
  do cp -i "${file}" "${file/mouse_gl/mouse_ncbim38_gl}"; 
done

mv data_ncbim38_mouse_2015-05-14/mouse_ncbim38*.n* ../igdata/database

#constant segments
cd ../constant_segments/

echo "[OK] Setting up database for mouse constant."
cp mouse_gl_C.fasta ../igdata/database/mouse_gl_C
makeblastdb -dbtype nucl -in ../igdata/database/mouse_gl_C
rm ../igdata/database/mouse_gl_C

./build_constant_db.pl -mysql_group mysql_igdb -lib ${library} -sp mouse -fasta mouse_gl_C.fasta

cd ../tags

./upload_tags.pl

cd ..

echo "[OK] Setting up other databases (species, plate layout, tags)."
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${library} --local_infile=1 < load_lib_tables.sql