
# Y-Ysss/directory-manager.sh

# Copyright (c) 2021 Y-Ysss

# This software is released under the MIT License.
# see Y-Ysss/directory-manager.sh/

# ===========================================================================================

# This is from Jonathan Peres's bash-yaml
# This is in script/yaml.sh, and it was started based on @pkuczynski gist(https://gist.github.com/pkuczynski/8665367).

# GitHub : https://github.com/jasperes/bash-yaml
# License : MIT License

# -------------------------------------------------------------------------------------------

# MIT License

# Copyright (c) 2017 Jonathan Peres

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ===========================================================================================

parse_yaml() {
   local yaml_file=$1
   local prefix=$2
   local s
   local w
   local fs

   s='[[:space:]]*'
   w='[a-zA-Z0-9_.-]*'
   fs="$(echo @ | tr @ '\034')"

   (
      sed -e '/- [^\“]'"[^\']"'.*: /s|\([ ]*\)- \([[:space:]]*\)|\1-\'$'\n''  \1\2|g' |
         sed -ne '/^--/s|--||g; s|\"|\\\"|g; s/[[:space:]]*$//g;' \
      -e 's/\$/\\\$/g' \
      -e "/#.*[\"\']/!s| #.*||g; /^#/s|#.*||g;" \
      -e "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)${s}[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
         awk -F"$fs" '{
            indent = length($1)/2;
            if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
            vname[indent] = $2;
            for (i in vname) {if (i > indent) {delete vname[i]}}
                if (length($3) > 0) {
                    vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
                    printf("%s%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, conj[indent-1], $3);
                }
            }' |
         sed -e 's/_=/+=/g' |
         awk 'BEGIN {
                FS="=";
                OFS="="
            }
            /(-|\.).*=/ {
                gsub("-|\\.", "_", $1)
            }
            { print }'
   ) <"$yaml_file"
}

unset_variables() {
   # Pulls out the variable names and unsets them.
   #shellcheck disable=SC2048,SC2206 #Permit variables without quotes
   local variable_string=($*)
   unset variables
   variables=()
   for variable in "${variable_string[@]}"; do
      tmpvar=$(echo "$variable" | grep '=' | sed 's/=.*//' | sed 's/+.*//')
      variables+=("$tmpvar")
   done
   for variable in "${variables[@]}"; do
      if [ -n "$variable" ]; then
         unset "$variable"
      fi
   done
}

create_variables() {
   local yaml_file="$1"
   local prefix="$2"
   local yaml_string
   yaml_string="$(parse_yaml "$yaml_file" "$prefix")"
   unset_variables "${yaml_string}"
   eval "${yaml_string}"
}

# ===========================================================================================

# This is based on Kris Johnson's bash-menu (in bash-menu.sh and bash-draw.sh).

# GitHub : https://github.com/barbw1re/bash-menu
# License : MIT License

# -------------------------------------------------------------------------------------------

# MIT License

# Copyright (c) 2018 Kris Johnson

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ===========================================================================================

declare -a Menu_items
declare -a Menu_Actions
declare -a Menu_args

readonly COLOR_FORE_DEFAULT=39
readonly COLOR_BACK_DEFAULT=49
readonly COLOR_BLACK=30
readonly COLOR_WHITE=97
readonly COLOR_RED=31
readonly COLOR_GREEN=32
readonly COLOR_YELLOW=33
readonly COLOR_BLUE=34
readonly COLOR_CYAN=36
readonly COLOR_GRAY=37
readonly COLOR_REVERSE=7
readonly COLOR_UNREVERSE=27

Menu_items[0]="Exit"
Menu_Actions[0]="exit_action"
Menu_args[0]="0"

item_count=1
item_index_last=0

Menu_header_text="Menu"

Fore_color=$COLOR_FORE_DEFAULT
Back_color=$((COLOR_FORE_DEFAULT + 10))
Header_fore_color=$COLOR_CYAN
Header_back_color=$Back_color
Item_fore_color=$Fore_color
Item_back_color=$Back_color
Item_hover_fore_color=$COLOR_BLACK
Item_hover_back_color=$((COLOR_CYAN + 10))

readonly ADD_LINE='echo -en'
readonly ADD_NEWLINE='echo -e'

function f_clear_screen() {
    $ADD_LINE "\033c"
}
function f_set_color() {
    local _color=$Fore_color
    local _bgColor=$Back_color

    if [[ -n "$1" && "$1" != "" ]]; then
        _color="$1"
    fi

    if [[ -n "$2" && "$2" != "" ]]; then
        _bgColor="$2"
    fi

    if [[ -n "$1" && "$1" != "" && -z "$2" ]]; then
        $ADD_LINE "\033[${_color}m"
    else
        $ADD_LINE "\033[${_color};${_bgColor}m"
    fi
}
function f_move_to() {
    $ADD_LINE "\033[${1};${2}H"
}
function f_draw_at() {
    [[ -z "$4" ]] && newLine=0 || newLine="$4"
    if [[ -n "$5" && "$5" != "" && -n "$6" && "$6" != "" ]]; then
        f_set_color $5 $6
    elif [[ -n "$5" && "$5" != "" ]]; then
        f_set_color $5
    fi
    f_move_to $1 $2
    f_draw "$3" "$newLine"
}
function f_draw() {
    if [[ -z "$2" || "$2" -eq 0 ]]; then
        $ADD_LINE "$1"
    else
        $ADD_NEWLINE "$1"
    fi
}


function f_display() {
    f_clear_screen
    f_set_color $Fore_color $Back_color

    f_draw_at 1 1 "$Menu_header_text" 0 $Header_fore_color $Header_back_color

    for item in $(seq 0 $item_index_last); do
        f_menu_item $item
    done
}

function f_menu_item() {
    local _item=$1
    local _top=$((_item + 2))
    local _menuText=${Menu_items[$_item]}

    f_draw_at $_top 2 "$_menuText" 0 $Item_fore_color $Item_back_color
}

function f_menu_item_hover() {
    local _item=$1
    local _top=$((_item + 2))
    local _menuText=${Menu_items[$_item]}
    f_draw_at $_top 2 "$_menuText" 0 $Item_hover_fore_color $Item_hover_back_color
}

function menu_handle_input() {
    local _choice=$1

    local _after=$((_choice + 1))
    [[ $_after -gt $item_index_last ]] && _after=0

    local _before=$((_choice - 1))
    [[ $_before -lt 0 ]] && _before=$item_index_last

    f_menu_item $_before
    f_menu_item $_after

    f_menu_item_hover $_choice

    local _key=""
    local _extra=""

    read -s -n1 _key 2>/dev/null >&2
    while read -s -n1 -t .05 _extra 2>/dev/null >&2; do
        _key="$_key$_extra"
    done

    local _esc_key=$(echo -en "\033")
    local _up_arrow_key=$(echo -en "\033[A")
    local _down_arrow_key=$(echo -en "\033[B")

    if [[ $_key = $_up_arrow_key ]]; then
        return $_before
    elif [[ $_key = $_down_arrow_key ]]; then
        return $_after
    elif [[ $_key = $_esc_key ]]; then
        if [[ $_choice -eq $item_index_last ]]; then
            _key=""
        else
            f_menu_item $_choice
            return $item_index_last
        fi
    elif [[ ${#_key} -eq 1 ]]; then
        for __index in $(seq 0 $item_index_last); do
            local _item=${Menu_items[$__index]}
            local _start_char=${_item:0:1}
            if [[ "$_key" = "$_start_char" ]]; then
                f_menu_item $_choice
                return $__index
            fi
        done
    fi

    if [[ "$_key" = "" ]]; then
        return 255
    fi

    return $_choice
}

function MenuInit() {
    Back_color=$((COLOR_FORE_DEFAULT + 10))
    Header_fore_color=$Fore_color
    Header_back_color=$Back_color
    Item_fore_color=$Fore_color
    Item_back_color=$Back_color
    item_count=${#Menu_items[@]}
    item_index_last=$((item_count - 1))
}

function MainLoop() {
    local _choice=0
    local _running=1

    f_display

    while [[ $_running -eq 1 ]]; do
        local caseMatch=$(shopt -p nocasematch)
        shopt -s nocasematch

        menu_handle_input $_choice
        local _new_choice=$?

        $caseMatch

        if [[ $_new_choice -eq 255 ]]; then
            f_clear_screen
            local _f_action=${Menu_actions[$_choice]}
            $_f_action ${Menu_items[$_choice]} ${Menu_args[$_choice]}
            _running=$?

            [[ $_running -eq 1 ]] && f_display

        elif [[ $_new_choice -lt $item_count ]]; then
            _choice=$_new_choice
        fi
    done
}

function cd_action() {
   echo "DirectoryManager : $1"
   cd $2
   exec bash
   return 0
}

function exit_action() {
   return 0
}

cd $(dirname $0)
echo "Dirmages"
create_variables ./directories.yaml


for i in "${!data__name[@]}"; do
   Menu_items[$i]=${data__name[$i]}
done

for i in "${!data__name[@]}"; do
   Menu_actions[$i]=cd_action
done

for i in "${!data__path[@]}"; do
   Menu_args[$i]=${data__path[$i]}
done

Menu_header_text="Directory-Manager"
MenuInit
MainLoop