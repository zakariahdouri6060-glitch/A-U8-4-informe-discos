#!/bin/bash
# =============================================================================
# A-U8-4: Informe de espacio en disco con envío por correo electrónico
# Descripción : Lee la ocupación de cada partición con df -h y envía un
#               informe por correo. Solo se notifican particiones con más
#               del 50 % de uso (puntos extra).
# Herramientas: ssmtp + mailutils
# Ejecución   : Cron todos los días a las 19:00
#               0 19 * * * /ruta/al/script/informe_discos.sh
# =============================================================================

# --------------------------------------------------------------------------- #
# CONFIGURACIÓN
# --------------------------------------------------------------------------- #
ADMIN_MAIL="vj.santonjaivorra@edu.gva.es"
HOSTNAME=$(hostname)
FECHA=$(date '+%Y-%m-%d %H:%M:%S')
UMBRAL=50          # Porcentaje mínimo de uso para incluir la partición
ASUNTO="[INFORME DISCOS] $HOSTNAME - $FECHA"

# --------------------------------------------------------------------------- #
# CABECERA DEL CUERPO DEL CORREO
# --------------------------------------------------------------------------- #
CUERPO="Informe de ocupación de discos - $HOSTNAME
Fecha y hora: $FECHA
Umbral de aviso: particiones con uso >= ${UMBRAL}%
============================================================

PARTICIONES CON MÁS DEL ${UMBRAL}% DE USO:
------------------------------------------------------------
"

# --------------------------------------------------------------------------- #
# LEER df -h Y FILTRAR PARTICIONES CON USO > UMBRAL
# Se omite la primera línea (cabecera) con tail -n +2
# La columna 5 contiene el porcentaje de uso (ej.: "72%")
# --------------------------------------------------------------------------- #
PARTICIONES_ALERTA=""

while IFS= read -r linea; do
    # Extraer el porcentaje (quitar el símbolo %)
    porcentaje=$(echo "$linea" | awk '{print $5}' | tr -d '%')

    # Comprobar que el valor es numérico antes de comparar
    if [[ "$porcentaje" =~ ^[0-9]+$ ]]; then
        if [ "$porcentaje" -ge "$UMBRAL" ]; then
            PARTICIONES_ALERTA="${PARTICIONES_ALERTA}${linea}\n"
        fi
    fi
done < <(df -h | tail -n +2)

# --------------------------------------------------------------------------- #
# DECIDIR SI HAY ALGO QUE INFORMAR
# --------------------------------------------------------------------------- #
if [ -z "$PARTICIONES_ALERTA" ]; then
    CUERPO="${CUERPO}(No hay particiones por encima del ${UMBRAL}% de uso. El sistema está en buen estado.)\n"
else
    # Añadir cabecera de columnas de df -h
    CABECERA_DF=$(df -h | head -n 1)
    CUERPO="${CUERPO}${CABECERA_DF}\n${PARTICIONES_ALERTA}"
fi

# --------------------------------------------------------------------------- #
# INFORME COMPLETO (todas las particiones) AL FINAL DEL CORREO
# --------------------------------------------------------------------------- #
CUERPO="${CUERPO}
============================================================
ESTADO COMPLETO DE TODOS LOS DISCOS (df -h):
------------------------------------------------------------
$(df -h)

============================================================
Informe generado automáticamente por cron en $HOSTNAME
"

# --------------------------------------------------------------------------- #
# ENVÍO DEL CORREO CON mailutils (comando mail)
# ssmtp debe estar configurado en /etc/ssmtp/ssmtp.conf
# --------------------------------------------------------------------------- #
echo -e "$CUERPO" | mail -s "$ASUNTO" "$ADMIN_MAIL"

# --------------------------------------------------------------------------- #
# LOG LOCAL (opcional) — registra cada ejecución en /var/log/informe_discos.log
# --------------------------------------------------------------------------- #
LOG="/var/log/informe_discos.log"
echo "[$FECHA] Informe enviado a $ADMIN_MAIL" >> "$LOG" 2>/dev/null || \
echo "[$FECHA] Informe enviado a $ADMIN_MAIL" >> /tmp/informe_discos.log

exit 0
