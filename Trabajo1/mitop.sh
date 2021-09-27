#!/bin/bash

function leerDatosSistema()
{
	leerTiemposSistema
	
	leerMemoriaSistema
}

function leerMemoriaSistema ()
{
	# Directorio donde se encuentran los datos
	dirMeminfo=/proc/meminfo
	
	# Memoria fisica total
	memTotal=$(awk '/MemTotal/ {print $2}' $dirMeminfo)

	# Memoria libre
	memLibre=$(awk '/MemFree/ {print $2}' $dirMeminfo)
	
	# Memoria buffer
	buffer=$(awk '/Buffers/ {print $2}' $dirMeminfo)

	# Memoria cache
	memCache=$(awk '/Cached/ {print $2}' $dirMeminfo | head -1)
	
	# Memoria utilizada
	memDisponible=$(awk '/MemAvailable/ {print $2}' $dirMeminfo)
	
	# Memoria intercambio total
	swapTotal=$(awk '/SwapTotal/ {print $2}' $dirMeminfo)
	
	# Memoria intercambio disponible
	swapLibre=$(awk '/SwapFree/ {print $2}' $dirMeminfo)
	
	# Memoria cache + memoria buffer
	cachBuffer=$(($memCache+$buffer))
	
	# Memoria utilizada
	memUtilizada=$(($memTotal-($memLibre+$cachBuffer)))
	
	# Memoria intercambio utilizada
	swapUtilizada=$(($swapTotal-$swapLibre))
}

function leerTiemposSistema ()
{	
	# Lectura de los datos referentes a los tiempos
	read CPU User Nice System Idle IOwait Irq Softirq Steal Guest GuestNice< /proc/stat
	tiemposCPU=$(printf "%s %s %s %s %s %s %s %s" $User $Nice $System $Idle $IOwait $Irq $Softirq $Steal)
	
	# Tiempo total sistema. Si se realiza la diferencia con alguna medida anterior se pierden 
	# los datos que no hayan tenido actividad
	tiempoTotalSistema=$(echo $tiemposCPU | awk '{print $1+$2+$3+$4+$5+$6+$7+$8}')
	
	pSistemaUser=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $1}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
	
	pSistemaNice=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $2}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
	
	pSistemaSyst=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $3}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
	
	pSistemaIdle=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $4}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')

	pSistemaIOwa=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $5}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
	
	pSistemaHirq=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $6}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
	
	pSistemaSirq=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $7}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
	
	pSistemaStea=$(echo "scale=2; 100*$(echo $tiemposCPU | awk '{print $8}')/$tiempoTotalSistema" | 
	bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
}

function leerDatosProcesos ()
{
	filtrarProcesos

	leerProcesos
}

function filtrarProcesos ()
{
	listaProcesos=$(ls -l /proc | awk '{print $9}' | grep "[0-9]$")
	sumatotalTiemposProcesos=0
	
	while read linea
	do		
		Proceso=$(echo $linea | awk '{print $1}')
		
		# Filtramos los ficheros no accesibles
		if [ -d /proc/$Proceso ]; then

			# Directorios a utilizar
			dirStat=/proc/$Proceso/stat
			
			# Se contabilizan los procesos
			let "numeroProcesos+=1"

			# Estado del proceso. Se cuenta cada tipo
			Estado=$(awk '{print $3}' $dirStat)
			
			case $Estado in
				R)
					let "running+=1"
				;;
				T)
					let "stopped+=1"
				;;
				t)
					let "stopped+=1"
				;;
				Z)
					let "zombie+=1"
				;;
				*)
					let "sleeping+=1"
				;;
			esac
			
			tProceso1[$Proceso]=$(cat $dirStat |awk '{print $1="", ($14+$15)}')

			tSistema1[$Proceso]=$(cat /proc/uptime |awk '{print ($1+$2)}')
		fi
		
	done <<< "$listaProcesos"
	
	sleep 1
	
	while read linea
	do		
		Proceso=$(echo $linea | awk '{print $1}')
		
		# Filtramos los ficheros no accesibles
		if [ -d /proc/$Proceso ]; then

			# Directorios a utilizar
			dirStat=/proc/$Proceso/stat
			
			tProceso2[$Proceso]=$(cat $dirStat |awk '{print $1="", ($14+$15)}')

			tSistema2[$Proceso]=$(cat /proc/uptime |awk '{print ($1+$2)}')
			
			# Diferencia de tiempos de proceso
			diferenciaP=$((tProceso2[$Proceso]-tProceso1[$Proceso]))
			
			# Diferencia de tiempos de sistema
			diferenciaS=$(echo "scale=0; (${tSistema2[$Proceso]}-${tSistema1[$Proceso]})" | bc)
			
			# Archivo temporal para poder reducir la lista de procesos
			printf "$Proceso $diferenciaP $diferenciaS\n" >> temp/procesosIniciales
		fi
		
	done <<< "$listaProcesos"s
	
	# Se filtra en este momento la lista
	listaProcesosFiltrada=$(cat temp/procesosIniciales | sort -k2 -nr | head -10)
}

function leerProcesos ()
{
	while read linea
	do
		Proceso=$(echo $linea | awk '{print $1}')
		diferenciaP=$(echo $linea | awk '{print $2}')
		diferenciaS=$(echo $linea | awk '{print $3}')

		# Filtramos los ficheros no accesibles
		if [ -d /proc/$Proceso ]; then

			# Directorios a utilizar
			dirStat=/proc/$Proceso/stat
			dirStatus=/proc/$Proceso/status
			
			# Usuario
			UsuarioID=$(awk '/Uid/ {print $2}' $dirStatus)
			Usuario=$(getent passwd $UsuarioID | cut -d: -f1)

			# Prioridad
			Prioridad=$(awk '{print $18}' $dirStat)
			if [ $Prioridad -lt "-1" ]; then
				Prioridad=rt
			fi

	 		# Niceness
			Niceness=$(awk '{print $19}' $dirStat)

			# Memoria Virtual
			MemoriaVirtual=$(awk '{print $23/1024}' $dirStat)

			# Memoria física
			MemoriaFisica=$(awk '/VmRSS/ {print $2}' $dirStatus)
			
			# Memoria compartida
			rssFile=$(awk '/RssFile/ {print $2}' $dirStatus)
			rssShmem=$(awk '/RssShmem/ {print $2}' $dirStatus)
			MemoriaCompartida=$((${rssFile:-0} + ${rssShmem:-0}))

			# Estado del proceso
			Estado=$(awk '{print $3}' $dirStat)

			# Porcentaje de uso de CPU. No se multiplica por 100 debido a las 
			# unidades en las que esta expresado el tiempo de sistema (segundos),
			# mientras que las del tiempo de usuario se corresponden a hercios
			PorcentajeCPU=$(echo "scale=2; $diferenciaP/$diferenciaS" |
			bc | awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
			
			# Porcentaje memoria
			if [ -z $MemoriaFisica ] || [ $MemoriaFisica -eq 0 ]; then
				PorcentajeMemoria=0,0
			else
				PorcentajeMemoria=$(echo "scale = 3; 100*($MemoriaFisica/$memTotal)" | bc | \
				awk '{printf "%.1f", $0}' | awk '{sub(/\./,",",$1)}1')
			fi
			
			# Tiempo de actividad
			tiempoEjecucion=$(cat $dirStat | awk '{print $1="", ($14+$15)}')
			diferenciaActividad=$(echo "scale=2; ($tiempoEjecucion/100)" |
			bc | awk '{printf "%.2f", $0}')		
			entera=${diferenciaActividad%.*}
			decimal=${diferenciaActividad#*.}
			tiempoActividad=$(printf '%d:%02d.%02d\n' \
			$(($entera/60)) $(($entera%60)) $((10#$decimal)))
	
			# Nombre
			Nombre=$(awk '/Name/ {$1=""; print $0}' $dirStatus)
			maximo=$((($(tput cols) - 67) - 1))
			if [ ${#Nombre} -gt $maximo ]; then
				Nombre=$(printf "%s+" ${Nombre:0:$maximo})
			fi
			
			# IMPRESION DE DATOS
			if [ $Estado = R ]; then
				printf "$(tput bold)%5s %-10s%2s %3s %7s %6s %6s %s %4s %4s %9s %s$(tput sgr0)\n" \
				${Proceso:-0} ${Usuario:-0} ${Prioridad:-0} ${Niceness:-0} ${MemoriaVirtual:-0} \
				${MemoriaFisica:-0} ${MemoriaCompartida:-0} ${Estado:-"-"} ${PorcentajeCPU:-"0,0"} \
				${PorcentajeMemoria:-"0,0"}	${tiempoActividad:-"0:00.00"} ${Nombre:-"-"} >> temp/procesos
			else 
				printf "%5s %-10s%2s %3s %7s %6s %6s %s %4s %4s %9s %s\n" \
				${Proceso:-0} ${Usuario:-0} ${Prioridad:-0} ${Niceness:-0} ${MemoriaVirtual:-0} \
				${MemoriaFisica:-0} ${MemoriaCompartida:-0} ${Estado:-"-"} ${PorcentajeCPU:-"0,0"} \
				${PorcentajeMemoria:-"0,0"}	${tiempoActividad:-"0:00.00"} ${Nombre:-"-"} >> temp/procesos
			fi
		fi
		
	done <<< "$listaProcesosFiltrada"
}

function mostrar ()
{
	boldOn=$(tput bold)
	boldOff=$(tput sgr0)
	anchoTerminal=$(tput cols)

	upTimeSistema=$(cat /proc/uptime | awk '{print int($1)}')

	if [ $upTimeSistema -ge 3600 ]; then
	
		tiempoActividadSistema=$(printf '%d:%02d\n' \
		$(($upTimeSistema/3600)) $(($upTimeSistema/60%60)) )
	else
		tiempoActividadSistema=$(printf "%d min\n" $(($upTimeSistema/60%60)))
	fi

	printf "\nTOP - %8s up %5s, %2s user,  load average: %3s, %3s, %3s\n" \
	$(date --date=@$(date +%s) | awk '{print $4}') \
	"$tiempoActividadSistema" \
	$(echo $(ls /run/user) | wc -w) \
	$(cat /proc/loadavg | awk '{print $1}' | awk '{sub(/\./,",",$1)}1') \
	$(cat /proc/loadavg | awk '{print $2}' | awk '{sub(/\./,",",$1)}1') \
	$(cat /proc/loadavg | awk '{print $3}' | awk '{sub(/\./,",",$1)}1') \

	printf "Tareas: %13s total, %13s ejecutar, %14s hibernar, %14s detener, %14s zombie\n" \
	"${boldOn}${numeroProcesos:-0}${boldOff}" \
	"${boldOn}${running:-0}${boldOff}" \
	"${boldOn}${sleeping:-0}${boldOff}" \
	"${boldOn}${stopped:-0}${boldOff}" \
	"${boldOn}${zombie:-0}${boldOff}"

	printf "%%Cpu(s): %14s usuario, %14s sist, %14s adecuado, %14s inact, %14s en espera, %14s hardw int, %14s softw int, %14s robar tiempo\n" \
	"${boldOn}${pSistemaUser:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaSyst:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaNice:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaIdle:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaIOwa:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaHirq:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaSirq:-"0,0"}${boldOff}" \
	"${boldOn}${pSistemaStea:-"0,0"}${boldOff}" | cut -c -$((($anchoTerminal*2)-26))
	
	printf "KiB Mem : %18s total, %18s free, %18s used, %18s buff/cache\n" \
	"${boldOn}${memTotal:-0}${boldOff}" \
	"${boldOn}${memLibre:-0}${boldOff}" \
	"${boldOn}${memUtilizada:-0}${boldOff}" \
	"${boldOn}${cachBuffer:-0}${boldOff}"
	
	printf "KiB Swap: %18s total, %18s free, %18s used. %18s avail Mem\n\n" \
	"${boldOn}${swapTotal:-0}${boldOff}" \
	"${boldOn}${swapLibre:-0}${boldOff}" \
	"${boldOn}${swapUtilizada:-0}${boldOff}" \
	"${boldOn}${memDisponible:-0}${boldOff}"
			
	linea=$(printf "%5s %-6s %4s %3s %7s %6s %6s %s %3s %3s %8s+ %s\n" PID USUARIO PR NI VIRT RES SHR S %CPU %MEM HORA ORDEN)

	t="$linea";
	echo -ne "\x1b[7m";
	echo -n "$t";{ tr </dev/zero \\0 \ | head -c $(bc <<<"$(stty -a <&3|grep -Po '(?<=columns )[0-9]+')-$(wc -c<<<"$t")+1"); } 3<&0;
	echo -e "\x1b[0m";

	cat temp/procesos | head -10
}

function principal ()
{
	if [ -d temp ]; then
		rm -r temp
	fi
	
	mkdir temp
	
	leerDatosSistema
	
	leerDatosProcesos
	
	mostrar
	
	rm -r temp
}

#reset

principal

# Comparacion con top
#top -n 1 | head -17

exit 0

