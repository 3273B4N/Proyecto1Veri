source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh;

#rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"` # ese comando destruye todos los archivos que no sean fuente, se debe descomentar al inicio y se debe comentar cada vez qeu se ejecute este archivo pq sino borra todo, solo se descomenta la primera vez que se usa el tb

#Esta parte permite aleatorizar la profundidad de la FIFO y el tamaño del paquete, comentar si no se necesita

DEPTH=$(( (RANDOM % 255) + 2 )) # aca se aleatoriza con profundidades de  2 a 256
#WIDTH=$(( (RANDOM % 255) + 2 )) # aca se aleatoriza con anchos de  2 a 256 ambiente no soporta anchos diferentes a 16 bits
#Nota: en bash el comando RANDOM genera un numero aleatorio entre 0 y 32767 al usar el operador de resto (%) se achica el rango de aleatorización de 0 a 254, como se requiere aleatorizar de 0 a 254 se suman + 2 para que quede de 2 a 256 como se pide, el parentesis $() le dice a la terminal que evalue es expresión
echo "Compilando con depth=$DEPTH " #y tamaño del paquete=$WIDTH" 

# Este comando compila el dut y el tb con tamaños aleatorios para la profundidad de la FIFO -pvalue es un flag de VCS que  modifica el parametro seleccionado en tiempo de compilación
vcs -Mupdate test_bench.sv -o salida -full64 -sverilog -kdb -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -pvalue+test_bench.depth=$DEPTH -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab 


#vcs -Mupdate test_bench.sv  -o salida  -full64 -sverilog  -kdb -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L  -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab # ;;; este comando compila el tb y el dut de forma regular

#vcs -Mupdate test_bench.sv  -o salida  -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 

#vcs -Mupdate test_simple_fifo.sv -o salida  -full64 -sverilog  -kdb -lca -debug_acc+all -debug_region+cell+encrypt -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 

./salida +RUN_ALL=1 # +ESCENARIO=provocar_overflow #este es el plusarg para seleccionar el escenario

#./salida -cm line+tgl+cond+fsm+branch+assert; #Aca se ponen los plusargs tira el ejecutable se va a usar cuando se tenga cobertura

#verdi -cov -covdir salida.vdb& # ; este comando se usa para abrir el archivo que tiene la cobertura 

