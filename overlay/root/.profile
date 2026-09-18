clear
printf '%s\n' 'Samsung 960 EVO firmware environment'
printf '%s\n' 'Starting Fumagician as root. The updater will ask before flashing.'
printf '%s\n\n' 'The NVMe safety check remains enabled.'

/usr/local/bin/fumagician || printf '%s\n' 'Fumagician exited; root shell remains available.'
exec /bin/sh
