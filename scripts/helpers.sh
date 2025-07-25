if [ -d "$HOME/.tmux/resurrect" ]; then
        default_resurrect_dir="$HOME/.tmux/resurrect"
else
        default_resurrect_dir="${XDG_DATA_HOME:-$HOME/.local/share}"/tmux/resurrect
fi
resurrect_dir_option="@resurrect-dir"

SUPPORTED_VERSION="1.9"
RESURRECT_FILE_PREFIX="tmux_resurrect"
RESURRECT_FILE_EXTENSION="txt"
_RESURRECT_DIR=""
_RESURRECT_FILE_PATH=""

d=$'\t;\t'

# helper functions
get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# Ensures a message is displayed for 5 seconds in tmux prompt.
# Does not override the 'display-time' tmux option.
display_message() {
	local message="$1"

	# display_duration defaults to 5 seconds, if not passed as an argument
	if [ "$#" -eq 2 ]; then
		local display_duration="$2"
	else
		local display_duration="5000"
	fi

	# saves user-set 'display-time' option
	local saved_display_time=$(get_tmux_option "display-time" "750")

	# sets message display time to 5 seconds
	tmux set-option -gq display-time "$display_duration"

	# displays message
	tmux display-message "$message"

	# restores original 'display-time' value
	tmux set-option -gq display-time "$saved_display_time"
}


supported_tmux_version_ok() {
	$CURRENT_DIR/check_tmux_version.sh "$SUPPORTED_VERSION"
}

remove_first_char() {
	echo "$1" | cut -c2-
}

capture_pane_contents_option_on() {
	local option="$(get_tmux_option "$pane_contents_option" "off")"
	[ "$option" == "on" ]
}

files_differ() {
	! cmp -s "$1" "$2"
}

get_grouped_sessions() {
	local grouped_sessions_dump="$1"
	export GROUPED_SESSIONS="${d}$(echo "$grouped_sessions_dump" | cut -f2 -d"$d" | tr "\\n" "$d")"
}

is_session_grouped() {
	local session_name="$1"
	[[ "$GROUPED_SESSIONS" == *"${d}${session_name}${d}"* ]]
}

# pane content file helpers

pane_contents_create_archive() {
	tar cf - -C "$(resurrect_dir)/save/" ./pane_contents/ |
		gzip > "$(pane_contents_archive_file)"
}

pane_content_files_restore_from_archive() {
	local archive_file="$(pane_contents_archive_file)"
	if [ -f "$archive_file" ]; then
		mkdir -p "$(pane_contents_dir "restore")"
		gzip -d < "$archive_file" |
			tar xf - -C "$(resurrect_dir)/restore/"
	fi
}

# paste buffers file helpers

paste_buffers_option_on() {
	local option="$(get_tmux_option "$paste_buffers_option" "off")"
	[ "$option" == "on" ]
}

paste_buffers_create_archive() {
	tar cf - -C "$(resurrect_dir)/save/" ./paste_buffers/ |
		gzip > "$(paste_buffers_archive_file)"
}

paste_buffers_restore_from_archive() {
	local archive_file="$(paste_buffers_archive_file)"
	if [ -f "$archive_file" ]; then
		restore_dir=$(paste_buffers_dir "restore")
		mkdir -p "${restore_dir}"
		gzip -d < "$archive_file" |
			tar xf - -C "$(resurrect_dir)/restore/"
		gzip -d < "$archive_file" | tar t | cut -d / -f 3 |
			sort -r | # restore buffers in order (first saved restored last)
			while read file_in_arch; do
				[ ! -f "${restore_dir}/${file_in_arch}" ] && continue # skip top level dir
				echo "${restore_dir}/${file_in_arch}"
		done
	fi
}

# path helpers

resurrect_dir() {
	if [ -z "$_RESURRECT_DIR" ]; then
		local path="$(get_tmux_option "$resurrect_dir_option" "$default_resurrect_dir")"
		# expands tilde, $HOME and $HOSTNAME if used in @resurrect-dir
		echo "$path" | sed "s,\\\\\$HOME,$HOME,g; s,\\\\\$HOSTNAME,$(hostname),g; s,\$HOME,$HOME,g; s,\$HOSTNAME,$(hostname),g; s,\~,$HOME,g"
	else
		echo "$_RESURRECT_DIR"
	fi
}
_RESURRECT_DIR="$(resurrect_dir)"

resurrect_file_path() {
	if [ -z "$_RESURRECT_FILE_PATH" ]; then
		local timestamp="$(date +"%Y%m%dT%H%M%S")"
		echo "$(resurrect_dir)/${RESURRECT_FILE_PREFIX}_${timestamp}.${RESURRECT_FILE_EXTENSION}"
	else
		echo "$_RESURRECT_FILE_PATH"
	fi
}
_RESURRECT_FILE_PATH="$(resurrect_file_path)"

last_resurrect_file() {
	echo "$(resurrect_dir)/last"
}

pane_contents_dir() {
	echo "$(resurrect_dir)/$1/pane_contents/"
}

pane_contents_file() {
	local save_or_restore="$1"
	local pane_id="$2"
	echo "$(pane_contents_dir "$save_or_restore")/pane-${pane_id}"
}

pane_contents_file_exists() {
	local pane_id="$1"
	[ -f "$(pane_contents_file "restore" "$pane_id")" ]
}

pane_contents_archive_file() {
	echo "$(resurrect_dir)/pane_contents.tar.gz"
}

paste_buffers_dir() {
	echo "$(resurrect_dir)/$1/paste_buffers/"
}

paste_buffer_file() {
	local save_or_restore="$1"
	local file_name="$2"
	echo "$(paste_buffers_dir "${save_or_restore}")/${file_name}"
}

paste_buffers_archive_file() {
	echo "$(resurrect_dir)/paste_buffers.tar.gz"
}

execute_hook() {
	local kind="$1"
	shift
	local args="" hook=""

	hook=$(get_tmux_option "$hook_prefix$kind" "")

	# If there are any args, pass them to the hook (in a way that preserves/copes
	# with spaces and unusual characters.
	if [ "$#" -gt 0 ]; then
		printf -v args "%q " "$@"
	fi

	if [ -n "$hook" ]; then
		eval "$hook $args"
	fi
}
