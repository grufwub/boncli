#!/bin/sh

check_env() {
  [ -z "$BONCLI_ROOT" ] && return 1
  [ -z "$FILE_PICKER" ] && return 1
  [ -z "$BONCLI_GIT" ] && return 1
  TEMP_DIR=$(get_temp_dir) || return 1
}

download_files() {
  TEMP_BONCLI=""
  TEMP_FILEPICKER=""
  TEMP_BONCLIGIT=""

  download "$TEMP_DIR/boncli" "$TEMP_BONCLI"             || return 1
  download "$TEMP_DIR/file_picker.py" "$TEMP_FILEPICKER" || return 1
  download "$TEMP_DIR/boncli_git.sh" "$TEMP_BONCLIGIT"   || return 1
}

replace_files() {
  local boncli_path

  [ ! -f "$TEMP_DIR/boncli" ]         && return 1
  [ ! -f "$TEMP_DIR/file_picker.py" ] && return 1
  [ ! -f "$TEMP_DIR/boncli_git.sh" ]  && return 1

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

if ( ! check_env ); then
  printf 'environment check failed...\n'
  return 1
fi

download_files || return 1
replace_files  || return 1
return 0