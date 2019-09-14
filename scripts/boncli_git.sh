#!/bin/sh

readonly DEFAULT_GITNAME='boncli sync client'
readonly DEFAULT_GITEMAIL='boncli@gmail.com'
readonly DEFAULT_GITBRANCH='sync'
readonly TEMPLATE_BRANCH='master-template'
readonly COMMIT_MSG='boncli sync client changes: see full commit for details'

usage()
{
  printf 'Usage: boncli git <COMMAND> <ARGS>

Options:
  --help         Show this screen

Commands:
  sync           Sync boncli sync directory with remote git repository
  repo           Git repository to use
  branch         Default git branch to use (any name except master)

  client_name    Name to show in git sync commits (default if null)
  client_email   Email to show in git sync commits (default if null)

  ssh_key        Git SSH access key location\n'
}

check_env()
{
  [ -z $BONCLI_ROOT ] && return 1
  [ -z $SYNC_DIR ] && return 1
  [ -z $BONCLI_TEMP ] && return 1
  [ -z $YQ_EXEC ] && return 1
  [ -z $BONCLI_GIT ] && return 1
  [ -z $CONF_FILE ] && return 1
  [ -z $BONCLI_GITURL ] && return 1

  if ( ! git --version > /dev/null 2>&1 ); then
    printf 'boncli git synchronization requires that git be installed, exiting...\n'
    return 1
  fi

  return 0
}

gitcmd()
{
  git -c "user.name=$GIT_NAME" -c "user.email=$GIT_EMAIL" "$@" > /dev/null 2>&1
}

git_checkout() {
  gitcmd checkout "$1" || git checkout -b "$1"
}

git_add_commit()
{
  git add .
  gitcmd commit -m "$COMMIT_MSG" -s -v
}

check_valid_input()
{
  printf 'test.branch' | grep -E -v -e '\s' -e '^\.' -e '\.{2,}' -e '\/$' -e '\.lock$' -e '\\' > /dev/null 2>&1
}

setup_git_repo()
{
  # Ensure we are in the sync directory
  cd "$SYNC_DIR" > /dev/null 2>&1

  # initialize git repository, set remote repo - return if failed
  gitcmd init || ( printf 'git repository setup failed!\n'; return 1 )
  gitcmd remote add origin "$GIT_REPO"

  # checkout supplied sync branch, add all files, commit, push to supplied repo - return if failed
  git_checkout
  git_add_commit
  gitcmd push origin "$GIT_BRANCH" || ( printf 'push to remote git branch "%s" failed!\n' "$GIT_BRANCH"; return 1 )

  # checkout master branch, download from master-template, unzip into place - return if failed
  git_checkout 'master'
  download 'template.zip' "$BONCLI_GITURL/archive/$TEMPLATE_BRANCH.zip" || return 1
  unzip 'template.zip' > /dev/null 2>&1
  mv -n 'template/*' . > /dev/null 2>&1

  # set required values in template README and bootstrap script
  sed -i 'README.md' -e "s|__URL__|$GIT_REPO|g"
  sed -i 'bootstrap.sh' -e "s|__URL__|$GIT_REPO|g"

  # add changes, commit and push - return if fail
  git_add_commit
  gitcmd push origin 'master' || ( printf 'push to remote git branch "master" failed!\n'; return 1 )

  # switch back to user sync repository
  git_checkout "$GIT_BRANCH"

  return 0
}

handle_merge_conflict()
{
  printf 'Remote changes in conflict with your local changes found.\n'

  # ensure we are in the sync directory
  cd "$SYNC_DIR" > /dev/null 2>&1

  handle_user_input() {
    local input_message user_input further_input

    input_message='How would you like to handle these changes?
1) Use remote changes and drop local changes
2) Use remote changes and save current local state to new branch
3) Use local changes and drop remote changes
4) View file differences
5) Exit\n'

    printf "$input_message"
    read user_input

    case "$user_input" in
      1)
        printf 'Resetting local changes and fast-forwarding to latest remote changes\n'
        gitcmd reset --hard
        gitcmd pull
        return 0
        ;;

      2)
        printf 'Moving local changes to new branch, what would you like to name this branch?\n'

        # Get new branch name
        read further_input
        check_valid_input "$further_input" || ( printf 'Invalid branch name!\n'; read_user_input )

        # Checkout new branch name and move changes there
        printf "Pushing local changes to new branch $further_input\n"
        gitcmd stash save

        git_checkout "$further_input"
        gitcmd stash pop
        git_add_commit
        gitcmd push origin "$further_input" || ( printf 'push to remote git branch "%s" failed!\n' "$1"; return 1 )

        # Switch back to original branch and pull remote changes
        printf 'Fast-forwarding to latest remote changes!\n'
        git_checkout "$GIT_BRANCH"
        gitcmd pull
        return 0
        ;;

      3)
        printf 'Force pushing local changes and ignoring remote changes!\n'
        git_add_commit
        gitcmd push origin "$GIT_BRANCH" --force || ( printf 'push to remote git branch "%s" failed!\n' "$1"; return 1 )
        return 0
        ;;

      4)
        printf 'view file differences\n'
        return 0
        ;;

      5)
        return 0
        ;;

      *)
        read_user_input
        ;;
    esac

    return 0
  }

  read_user_input || return 1
}

check_ssh_key()
{

}

setup_git_variables()
{
  GIT_REPO=$(read_yaml_conf 'git.repo')
  [ "$GIT_REPO" = '' ] && ( printf 'boncli git sync repository not set!\n'; return 1 )

  GIT_BRANCH=$(read_yaml_conf 'git.branch')
  [ "$GIT_BRANCH" = '' ] && GIT_BRANCH=$DEFAULT_GITBRANCH

  GIT_NAME=$(read_yaml_conf 'git.client_name')
  [ "$GIT_NAME" = '' ] && GIT_NAME=$DEFAULT_GITNAME

  GIT_EMAIL=$(read_yaml_conf 'git.client_email')
  [ "$GIT_EMAIL" = '' ] && GIT_EMAIL=$DEFAULT_GITEMAIL

  return 0
}

git_sync()
{
  local merge_str

  # check ssh key exists (and is valid?)
  check_ssh_key || return 1

  # ensure all required variables set (either from config file or default values)
  setup_git_variables || return 1

  # ensure sync directory is initialized as git repo, setup if not
  if ( ! git status ); then
    printf 'boncli sync directory not setup for git, initializing!\n'
    setup_git_repo || ( printf 'boncli git init failed\n'; return 1 )
  fi

  # ensure we're in sync directory
  cd "$SYNC_DIR" > /dev/null 2>&1

  # ensure we're on the right branch (create if necessary)
  git_checkout

  # fetch latest changes - return if fail
  git fetch origin || ( printf 'boncli git fetch failed!\n'; return 1 )

  # check if changes and handle
  if ( git status | grep -e '^Your branch is behind.*and can be fast-forwarded' > /dev/null 2>&1 ); then
    merge_str=$(gitcmd pull)
    if ( gitcmd pull | grep 'error: Your local changes to the following files would be overwritten' > /dev/null 2>&1 ); then
      handle_merge_conflict || return 1
    else
      printf 'Remote changes successfully merged!\n'
    fi
  fi

  # add all changes, commit and push - return if fail
  git_add_commit
  gitcmd push origin "$GIT_BRANCH" || ( printf 'push to remote git branch "%s" failed!\n' "$GIT_BRANCH"; return 1 )

  return 0
}

main()
{
  local result

  case "$1" in
    'sync')
      git_sync
      result=$?
      ;;

    'client_name')
      shift 1
      update_yaml_conf 'git.client_name' $*
      result=$?
      ;;

    'client_email')
      shift 1
      update_yaml_conf 'git.client_email' $*
      result=$?
      ;;

    'repo')
      shift 1
      update_yaml_conf 'git.repo' $*
      result=$?
      ;;

    'branch')
      shift 1
      update_yaml_conf 'git.branch' $*
      result=$?
      ;;

    'ssh_key')
      shift 1
      update_yaml_conf 'git.ssh_key' $*
      result=$?
      ;;

    '--help'|*)
      usage
      result=0
      ;;
  esac

  return $result
}

check_env && main $@
return $?