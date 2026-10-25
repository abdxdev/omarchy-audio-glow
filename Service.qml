import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Runs the speaker-driven glow preview and owns its settings.
// The widget talks to this instance directly; status is also reachable over
// IPC: qs ipc call abdxdev.audio-glow status
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool ipcEnabled: true

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || (home + "/.local/state")
  readonly property string stateDir: stateHome + "/omarchy"
  readonly property string statePath: stateDir + "/edge-glow.json"
  readonly property string pluginDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : home + "/.config/omarchy/plugins/io.github.abdxdev.edge-glow"
  // The preview ships inside the plugin, so enabling it does not depend on
  // anything having been installed into ~/.local/bin.
  readonly property string bundledScript: pluginDir + "/bin/audio-glow"
  readonly property string scriptPath: Quickshell.env("SUPERWHISPER_GLOW_PREVIEW")
    || bundledScript

  // Desired state, persisted between sessions.
  property bool enabled: true
  property string mode: "empty"
  property bool mediaOnly: false
  property int intensity: 100

  property bool ready: false
  property bool loading: false
  property bool stopping: false
  property bool pendingRestart: false
  property string lastError: ""

  readonly property bool running: preview.running
  readonly property var mediaPlayers: Mpris.players ? Mpris.players.values : []
  readonly property bool mediaDetected: {
    for (var i = 0; i < mediaPlayers.length; i++) {
      var player = mediaPlayers[i]
      if (player && (player.trackTitle || player.trackArtist)) return true
    }
    return false
  }
  readonly property bool shouldRun: enabled

  function normalisedMode(value) {
    return String(value) === "always" ? "always" : "empty"
  }

  function normalisedIntensity(value) {
    var number = Number(value)
    if (!isFinite(number)) number = 100
    return Math.max(0, Math.min(200, Math.round(number)))
  }

  function statusObject() {
    return {
      enabled: enabled,
      running: running,
      mode: mode,
      mediaOnly: mediaOnly,
      intensity: intensity,
      mediaDetected: mediaDetected,
      script: scriptPath,
      error: lastError
    }
  }

  function status() {
    return JSON.stringify(statusObject())
  }

  function setEnabled(value) {
    enabled = !!value
    return status()
  }

  function setMode(value) {
    mode = normalisedMode(value)
    return status()
  }

  function setMediaOnly(value) {
    mediaOnly = !!value
    return status()
  }

  function setIntensity(value) {
    intensity = normalisedIntensity(value)
    return status()
  }

  function toggle() {
    enabled = !enabled
    return status()
  }

  function applyState(raw) {
    loading = true
    var parsed = {}
    try {
      parsed = JSON.parse(String(raw || "{}"))
    } catch (error) {
      parsed = {}
    }
    enabled = typeof parsed.enabled === "boolean" ? parsed.enabled : true
    mode = normalisedMode(parsed.mode)
    mediaOnly = typeof parsed.mediaOnly === "boolean" ? parsed.mediaOnly : false
    intensity = normalisedIntensity(
      parsed.intensity === undefined ? 100 : parsed.intensity)
    loading = false
    ready = true
    applyNow()
  }

  function persist() {
    if (!ready || loading) return
    store.setText(JSON.stringify({
      enabled: enabled,
      mode: mode,
      mediaOnly: mediaOnly,
      intensity: intensity
    }) + "\n")
  }

  function scheduleSave() {
    if (!loading) saveTimer.restart()
  }

  function stopPreview() {
    pendingRestart = false
    if (preview.running) {
      stopping = true
      preview.running = false
    }
  }

  function launch() {
    if (!ready || !shouldRun) return
    lastError = ""
    preview.command = [
      scriptPath,
      "0",
      "edgeGlow",
      "--mode",
      mode === "empty" ? "empty" : "always",
      "--intensity",
      String(intensity)
    ]
    preview.running = true
  }

  function applyNow() {
    if (!ready) return
    if (!shouldRun) {
      stopPreview()
      return
    }
    if (preview.running) {
      // Restart so the new mode/intensity takes effect. The relaunch waits for
      // the old process to exit, which also releases the single-instance lock.
      pendingRestart = true
      stopping = true
      preview.running = false
      return
    }
    checkScript.running = true
  }

  onEnabledChanged: if (!loading) {
    scheduleSave()
    applyNow()
  }
  onModeChanged: if (!loading) {
    scheduleSave()
    applyNow()
  }
  onMediaOnlyChanged: if (!loading) {
    scheduleSave()
    applyNow()
  }
  onIntensityChanged: if (!loading) {
    scheduleSave()
    applyNow()
  }
  onMediaDetectedChanged: applyNow()

  Component.onCompleted: {
    mkdir.running = true
    // FileView loads the state on its own; onLoadFailed covers a first run.
  }

  Component.onDestruction: stopPreview()

  FileView {
    id: store

    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false

    onLoaded: root.applyState(text())
    onLoadFailed: root.applyState("")
  }

  Process {
    id: mkdir

    command: ["/usr/bin/mkdir", "-p", root.stateDir]
  }

  Process {
    id: checkScript

    command: ["/usr/bin/test", "-x", root.scriptPath]

    onExited: function(exitCode) {
      if (!root.shouldRun) return
      if (exitCode !== 0) {
        root.lastError = "Preview script not found: " + root.scriptPath
        return
      }
      root.launch()
    }
  }

  Process {
    id: preview

    stderr: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "")
          root.lastError = message.split("\n")[0]
      }
    }

    onExited: function(exitCode) {
      if (root.stopping) {
        root.stopping = false
        if (root.pendingRestart) {
          root.pendingRestart = false
          if (root.shouldRun) checkScript.running = true
        }
        return
      }
      if (!root.shouldRun) return
      if (root.lastError === "")
        root.lastError = "Preview stopped unexpectedly (exit code " + exitCode + ")"
    }
  }

  Timer {
    id: saveTimer

    interval: 150
    onTriggered: root.persist()
  }

  IpcHandler {
    enabled: root.ipcEnabled
    target: "abdxdev.audio-glow"

    function status(): string {
      return root.status()
    }

    function toggle(): string {
      return root.toggle()
    }

    function enable(): string {
      return root.setEnabled(true)
    }

    function disable(): string {
      return root.setEnabled(false)
    }

    function showAlways(): string {
      return root.setMode("always")
    }

    function showOnEmpty(): string {
      return root.setMode("empty")
    }

    function setMediaOnly(value: bool): string {
      return root.setMediaOnly(value)
    }

    function enableMediaOnly(): string {
      return root.setMediaOnly(true)
    }

    function disableMediaOnly(): string {
      return root.setMediaOnly(false)
    }

    function brighter(): string {
      return root.setIntensity(root.intensity + 10)
    }

    function dimmer(): string {
      return root.setIntensity(root.intensity - 10)
    }

    function resetIntensity(): string {
      return root.setIntensity(100)
    }
  }
}
