#!/bin/sh

check_update_env() {
  [ -z "$BONCLI_ROOT" ]      && return 1
  [ -z "$FILE_PICKER" ]      && return 1
  [ -z "$BONCLI_GIT" ]       && return 1
  [ -z "$BONCLI_GITURL" ]    && return 1
  [ -z "$BONCLI_GITBRANCH" ] && return 1
  TEMP_DIR=$(get_temp_dir)   || return 1
  return 0
}

download_files() {
  local url="$BONCLI_GIT/raw/$BONCLI_GITBRANCH"

  TEMP_BONCLI="$TEMP_DIR/boncli"
  TEMP_FILEPICKER="$TEMP_DIR/file_picker.py"
  TEMP_BONCLIGIT="$TEMP_DIR/boncli_git.sh"

  printf 'downloading files...\n'

  printf '-> latest boncli script\n'
  download "$TEMP_BONCLI" "$url/boncli" || return 1

  printf '-> latest file_picker.py script\n'
  download "$TEMP_FILEPICKER" "$url/scripts/file_picker.py" || return 1

  printf '-> latest boncli_git.sh script\n'
  download "$TEMP_BONCLIGIT" "$url/scripts/boncli_git.sh" || return 1
}

replace_files() {
  local boncli_path

  [ ! -f "$TEMP_BONCLI" ]     && return 1
  [ ! -f "$TEMP_FILEPICKER" ] && return 1
  [ ! -f "$TEMP_BONCLIGIT" ]  && return 1

  boncli_path=$(which boncli)
  if [ ! -w "$BONCLI_PATH" ]; then
    # Path not writeable, try sudo, return if fail
    sudo -E mv "$TEMP_BONCLI" "$boncli_path" > /dev/null 2>&1 || return 1
  else
    mv "$TEMP_BONCLI" "$boncli_path" > /dev/null 2>&1         || return 1
  fi

  mv "$TEMP_FILEPICKER" "$FILE_PICKER" > /dev//null 2>&1 || return 1
  mv "$TEMP_BONCLIGIT" "$BONCLI_GIT" > /dev/null 2>&1    || return 1
}

printf 'updater script:\n'

#if ( ! check_update_env ); then
#  printf 'environment check failed...\n'
#  return 1
#fi

check_update_env
download_files || return 1
replace_files  || return 1
return 0