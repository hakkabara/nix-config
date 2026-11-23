# dms-bar-follow – keep the DMS "default" bar on the main monitor and a
# mirrored "secondary" bar (minus some widgets) on all other monitors.
#
# DMS assigns bars by output name only, but VMware names the output that
# hosts the VM window Virtual-1, so names swap with window placement.  The
# main monitor is therefore picked by size: the active output with the most
# pixels.  settings.json is rewritten only when the assignment changes; DMS
# watches the file and reloads it.
#
# Env: DMS_BAR_MAIN_ONLY_WIDGETS = comma-separated widget ids for the main bar
# only (no JSON: systemd strips quotes from Environment= values).

settings="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/settings.json"
hide="$(jq -cn --arg s "${DMS_BAR_MAIN_ONLY_WIDGETS:-}" '$s | split(",") | map(select(. != ""))')"

apply() {
  local outputs main others new
  outputs="$(niri msg --json outputs)" || return 0
  main="$(jq -r '
    [ (if type == "object" then [.[]] else . end)[]
      | select(.logical != null and .current_mode != null)
      | { name, px: (.modes[.current_mode] | .width * .height) } ]
    | sort_by(-.px, .name) | .[0].name // empty' <<<"$outputs")"
  [ -n "$main" ] || return 0
  # With one active output nothing has to change: the main bar shows on the
  # last display anyway and the secondary bar hides there.  Not rewriting
  # keeps the bars calm while VMware drops and re-adds a monitor (Windows
  # lock) or the monitor helper switches an output off and on.
  [ "$(jq '[ (if type == "object" then [.[]] else . end)[] | select(.logical != null) ] | length' <<<"$outputs")" -ge 2 ] || return 0
  others="$(jq -c --arg main "$main" '
    [ (if type == "object" then [.[]] else . end)[]
      | select(.logical != null) | .name | select(. != $main) ] | sort' <<<"$outputs")"

  [ -f "$settings" ] && jq empty "$settings" 2>/dev/null || return 0

  new="$(jq --arg main "$main" --argjson others "$others" --argjson hide "$hide" '
    def wid: if type == "string" then . else .id end;
    def strip: map(select((wid as $id | $hide | index($id)) | not));
    if (.barConfigs | type) != "array" then .
    else
      ([.barConfigs[] | select(.id == "default")] | first) as $d
      | if $d == null then .
        else
          .barConfigs |= (
            map(select(.id != "secondary"))
            | map(if .id == "default"
                then .screenPreferences = [$main] | .showOnLastDisplay = true
                else . end)
          )
          | .barConfigs += [
              $d
              | .id = "secondary"
              | .name = "Secondary Bar"
              | .screenPreferences = $others
              | .showOnLastDisplay = false
              | .hideOnLastDisplay = true
              | .leftWidgets = ((.leftWidgets // []) | strip)
              | .centerWidgets = ((.centerWidgets // []) | strip)
              | .rightWidgets = ((.rightWidgets // []) | strip)
            ]
        end
    end' "$settings")" || return 0

  if [ "$(jq -S . <<<"$new")" != "$(jq -S . "$settings")" ]; then
    printf '%s\n' "$new" >"$settings.tmp"
    mv "$settings.tmp" "$settings"
    echo "dms-bar-follow: main=$main others=$others"
  fi
}

apply

# Any niri event (output hotplug moves workspaces) triggers a re-check after
# 1 s of quiet; the 30 s read timeout is the fallback poll.  The loop ends
# when niri closes the stream, and systemd restarts the service.
while IFS= read -r -t 30 _ || [ $? -gt 128 ]; do
  for _ in $(seq 1 20); do
    IFS= read -r -t 1 _ || break
  done
  apply
done < <(niri msg --json event-stream)
exit 1
