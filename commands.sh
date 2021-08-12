nix-shell -p rustc cargo pkgconfig openssl postgresql yarn

cargo build --release

psql --host=/home/bill/db -c "create user lemmy with password 'password' superuser;" -U postgres


# Create a database with the data stored in the current directory
initdb -D db/mydb

# Start PostgreSQL running as the current user
# and with the Unix socket in the current directory
pg_ctl -D db/mydb -l logfile -o "--unix_socket_directories='$PWD'" start

# Create a database with current location for socket
createdb --host=. lemmy

pg_ctl -D db/mydb stop

psql --host=/workspace/lemmy --dbname=lemmy -c "CREATE ROLE lemmy"

psql --host=/workspace/lemmy --dbname=lemmy -c "ALTER ROLE 'lemmy' WITH LOGIN;"