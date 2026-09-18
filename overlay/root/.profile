clear
printf '%s\n' 'Samsung NVMe firmware environment'
printf '%s\n' 'Starting Fumagician as root. It will ask for confirmation before'
printf '%s\n\n' 'flashing, then report whether the flash was verified.'

/usr/local/bin/fumagician || printf '%s\n' 'Fumagician exited; root shell remains available.'
exec /bin/sh
