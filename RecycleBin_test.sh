#!/bin/bash 


RECYCLE_BIN_DIR="$HOME/.recycle_bin" 
FILES_DIR="$RECYCLE_BIN_DIR/files" 
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db" 
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recycle.log"
 
# Color codes for output (optional) 
RED='\033[0;31m' 
GREEN='\033[0;32m' 
YELLOW='\033[1;33m' 
NC='\033[0m' # No Color 
 
################################################# 
# Function: initialize_recyclebin 
# Description: Creates recycle bin directory structure 
# Parameters: None 
# Returns: 0 on success, 1 on failure 
################################################# 
initialize_recyclebin() { 
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then 
        mkdir -p "$FILES_DIR"


        touch "$METADATA_FILE" 
        echo "# Recycle Bin Metadata" > "$METADATA_FILE" 
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"

        touch "$CONFIG_FILE"    #criar um config file caso este não exista
        echo "# Recycle Bin Configuration" > "$CONFIG_FILE"     #dar um cabeçalho tal como no metadata
        echo 'RECYCLE_BIN_DIR="$HOME/.recycle_bin"' >> "$CONFIG_FILE"    #adicionar ao config o caminho do diretorio do recicle bin
        echo 'FILES_DIR="$RECYCLE_BIN_DIR/files"' >> "$CONFIG_FILE"    #adicionar ao config o caminho do diretorio files
        echo 'METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"' >> "$CONFIG_FILE"    #adicionar ao config o caminho do ficheiro metadata
        echo "MAX_SIZE_MB=1024" >> "$CONFIG_FILE"   #adicionar ao config o tamaho maximo do ficheiros que podem ir para o recycle bin
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"  #adicionar o tempo limite em que um ficheiro pode ficar dentro do recycle bin
        echo 'CONFIG_FILE="$RECYCLE_BIN_DIR/config"' >> "$CONFIG_FILE" #adicionar ao config o seu proprio config

        touch "$LOG_FILE" #cria o ficheiro recyclebin.log vazio caso este não exista

        echo -e "${GREEN}Recycle bin initialized at $RECYCLE_BIN_DIR${NC}" #Alteração da função original para a mensagem de sucesso ser verde
        return 0 
    fi 
    return 0 
}


main() { 
    initialize_recyclebin
} 
 
main "$@"