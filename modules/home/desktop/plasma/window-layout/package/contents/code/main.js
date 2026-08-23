const handled = {};
const quickTileQueue = [];
const quickTileQueued = {};
const quickTileTimers = [];
let quickTileBusy = false;

const QUICK_TILE_RETRY_DELAYS = [
  500,
  1000,
  2000,
  5000,
];
const watched = {};
const unavailableSignals = {};


function text(value) {
  return String(value || "").toLowerCase();
}


function windowKey(window) {
  return String(
    window.internalId ||
      (
        window.resourceClass +
        ":" +
        window.caption
      ),
  );
}


function classMatches(
  value,
  candidates,
) {
  return (
    candidates.indexOf(value) !== -1
  );
}


function browserIdentity(value) {
  return classMatches(
    value,
    [
      "floorp",
      "firefox",
      "chromium",
      "chromium-browser",
      "google-chrome",
      "google-chrome-stable",
      "vivaldi",
      "vivaldi-stable",
    ],
  );
}


function isManageableMainWindow(window) {
  if (
    !window ||
    !window.normalWindow ||
    window.specialWindow
  ) {
    return false;
  }

  if (
    window.popupWindow ||
    window.modal ||
    window.transient
  ) {
    return false;
  }

  return true;
}


function classify(window) {
  if (!isManageableMainWindow(window)) {
    return null;
  }

  const cls =
    text(window.resourceClass);

  const name =
    text(window.resourceName);

  const caption =
    text(window.caption);

  const desktopFile =
    text(window.desktopFileName);


  // Kitty's own config-error helper is not a terminal workspace.
  if (
    cls === "kitty" &&
    caption.indexOf(
      "errors parsing configuration",
    ) !== -1
  ) {
    return null;
  }


  // Floorp Web Apps keep the normal Floorp class.
  if (
    cls === "floorp" &&
    caption.indexOf("whatsapp") !== -1
  ) {
    return {
      desktop: 5,
      label: "WhatsApp",
      maximize: true,
    };
  }


  if (
    browserIdentity(cls) ||
    browserIdentity(name) ||
    browserIdentity(desktopFile)
  ) {
    return {
      desktop: 1,
      label: "Browser",
      maximize: true,
    };
  }


  if (
    classMatches(
      cls,
      [
        "kitty",
        "konsole",
        "org.kde.konsole",
      ],
    ) ||
    classMatches(
      name,
      [
        "kitty",
        "konsole",
        "org.kde.konsole",
      ],
    )
  ) {
    return {
      desktop: 2,
      label: "Terminal",
      maximize: true,
    };
  }


  if (
    cls === "md.obsidian" ||
    desktopFile.indexOf(
      "obsidian",
    ) !== -1
  ) {
    return {
      desktop: 3,
      label: "Obsidian",
      maximize: true,
    };
  }


  if (
    cls.indexOf("equibop") !== -1 ||
    cls.indexOf("discord") !== -1 ||
    desktopFile.indexOf(
      "equibop",
    ) !== -1 ||
    desktopFile.indexOf(
      "discord",
    ) !== -1
  ) {
    return {
      desktop: 4,
      label: "Discord",
      maximize: true,
    };
  }


  if (
    cls === "signal" ||
    desktopFile.indexOf(
      "signal",
    ) !== -1
  ) {
    return {
      desktop: 6,
      label: "Signal",
      quickTile: "left",
    };
  }


  if (
    cls.indexOf(
      "telegram",
    ) !== -1 ||
    desktopFile.indexOf(
      "telegram",
    ) !== -1
  ) {
    return {
      desktop: 6,
      label: "Telegram",
      quickTile: "right",
    };
  }


  if (
    cls === "steam" ||
    desktopFile === "steam"
  ) {
    return {
      desktop: 7,
      label: "Steam",

      // Steam Friends/Settings etc. stay on desktop 7,
      // but only the main Steam window is maximized.
      maximize:
        caption === "steam",
    };
  }


  // Desktop 8 is intentionally a "Mail" role.
  // Thunderbird is current, KMail/Evolution are future-ready.
  if (
    cls === "thunderbird" ||
    desktopFile.indexOf(
      "thunderbird",
    ) !== -1 ||

    cls === "org.kde.kmail2" ||
    desktopFile.indexOf(
      "kmail",
    ) !== -1 ||

    cls === "evolution" ||
    desktopFile.indexOf(
      "evolution",
    ) !== -1
  ) {
    return {
      desktop: 8,
      label: "Mail",
      maximize: true,
    };
  }


  if (
    cls === "bitwarden" ||
    desktopFile.indexOf(
      "bitwarden",
    ) !== -1
  ) {
    return {
      desktop: 10,
      label: "Bitwarden",
      maximize: true,
    };
  }


  return null;
}


function signature(target) {
  return [
    target.desktop,
    target.quickTile || "none",
    target.maximize
      ? "max"
      : "normal",
    target.label,
  ].join(":");
}


function connectSignal(
  owner,
  signalName,
  callback,
) {
  if (!owner) {
    return false;
  }

  const signal =
    owner[signalName];


  if (
    signal &&
    signal.connect !== undefined
  ) {
    try {
      signal.connect(callback);

      return true;

    } catch (error) {
      print(
        "hakkabara-window-layout: failed to connect " +
          signalName +
          ": " +
          error,
      );
    }
  }


  if (!unavailableSignals[signalName]) {
    unavailableSignals[signalName] =
      true;

    print(
      "hakkabara-window-layout: signal unavailable: " +
        signalName,
    );
  }


  return false;
}


function assignDesktop(
  window,
  number,
) {
  if (
    workspace.desktops.length <
    number
  ) {
    print(
      "hakkabara-window-layout: desktop " +
        number +
        " is unavailable",
    );

    return false;
  }


  window.desktops = [
    workspace.desktops[
      number - 1
    ],
  ];


  return true;
}


function maximizeWindow(window) {
  if (
    !window.maximizable ||
    window.minimized ||
    window.hidden
  ) {
    return false;
  }


  if (window.fullScreen) {
    window.fullScreen =
      false;
  }


  window.setMaximize(
    true,
    true,
  );


  return true;
}


function later(
  milliseconds,
  callback,
) {
  if (
    typeof QTimer ===
    "undefined"
  ) {
    print(
      "hakkabara-window-layout: QTimer unavailable",
    );

    return false;
  }


  const timer =
    new QTimer();


  timer.interval =
    milliseconds;

  timer.singleShot =
    true;


  timer.timeout.connect(
    function () {
      const index =
        quickTileTimers.indexOf(
          timer,
        );


      if (index !== -1) {
        quickTileTimers.splice(
          index,
          1,
        );
      }


      callback();
    },
  );


  quickTileTimers.push(
    timer,
  );

  timer.start();


  return true;
}


function isManagedWindow(window) {
  return (
    window &&
    workspace.stackingOrder.indexOf(
      window,
    ) !== -1
  );
}


function quickTileGeometryMatches(
  window,
  side,
) {
  if (
    !isManagedWindow(window)
  ) {
    return false;
  }


  const geometry =
    window.frameGeometry;

  const area =
    workspace.clientArea(
      KWin.MaximizeArea,
      window,
    );

  const halfWidth =
    area.width / 2;

  const tolerance =
    8;


  const widthOkay =
    Math.abs(
      geometry.width -
        halfWidth,
    ) <= tolerance;

  const heightOkay =
    Math.abs(
      geometry.height -
        area.height,
    ) <= tolerance;

  const yOkay =
    Math.abs(
      geometry.y -
        area.y,
    ) <= tolerance;


  let xOkay =
    false;


  if (side === "left") {
    xOkay =
      Math.abs(
        geometry.x -
          area.x,
      ) <= tolerance;
  }


  if (side === "right") {
    xOkay =
      Math.abs(
        geometry.x -
          (
            area.x +
            halfWidth
          ),
      ) <= tolerance;
  }


  return (
    widthOkay &&
    heightOkay &&
    yOkay &&
    xOkay
  );
}


function restoreQuickTileContext(
  previousDesktop,
  previousActive,
) {
  if (
    previousDesktop &&
    workspace.desktops.indexOf(
      previousDesktop,
    ) !== -1
  ) {
    workspace.currentDesktop =
      previousDesktop;
  }


  if (
    previousActive &&
    isManagedWindow(
      previousActive,
    )
  ) {
    const desktops =
      previousActive.desktops;


    if (
      !previousDesktop ||
      !desktops ||
      desktops.length === 0 ||
      desktops.indexOf(
        previousDesktop,
      ) !== -1
    ) {
      workspace.activeWindow =
        previousActive;
    }
  }
}


function finishQuickTileJob(
  job,
  success,
) {
  delete quickTileQueued[
    job.key
  ];


  quickTileBusy =
    false;


  if (
    success &&
    isManagedWindow(
      job.window,
    )
  ) {
    // Re-enter normal layout processing. The geometry
    // post-condition now succeeds, so only here is the
    // window considered handled.
    applyLayout(
      job.window,
    );

  } else {
    handled[job.key] =
      "pending:" +
      job.wanted;


    print(
      "hakkabara-window-layout: " +
        job.target.label +
        " quick-tile " +
        job.side +
        " still pending after retries",
    );
  }


  later(
    100,
    processQuickTileQueue,
  );
}


function scheduleQuickTileAttempt(
  job,
) {
  if (
    job.attempt >=
    QUICK_TILE_RETRY_DELAYS.length
  ) {
    finishQuickTileJob(
      job,
      false,
    );

    return;
  }


  const delay =
    QUICK_TILE_RETRY_DELAYS[
      job.attempt
    ];


  job.attempt +=
    1;


  print(
    "hakkabara-window-layout: " +
      job.target.label +
      " quick-tile " +
      job.side +
      " attempt " +
      job.attempt +
      "/" +
      QUICK_TILE_RETRY_DELAYS.length +
      " in " +
      delay +
      "ms",
  );


  if (
    !later(
      delay,
      function () {
        runQuickTileAttempt(
          job,
        );
      },
    )
  ) {
    finishQuickTileJob(
      job,
      false,
    );
  }
}


function runQuickTileAttempt(
  job,
) {
  const window =
    job.window;


  if (
    !isManagedWindow(window)
  ) {
    finishQuickTileJob(
      job,
      false,
    );

    return;
  }


  // A previous attempt may have succeeded slightly after
  // its verification timer. Never invoke the same shortcut
  // again if the geometry is already correct.
  if (
    quickTileGeometryMatches(
      window,
      job.side,
    )
  ) {
    finishQuickTileJob(
      job,
      true,
    );

    return;
  }


  if (window.hidden) {
    scheduleQuickTileAttempt(
      job,
    );

    return;
  }


  if (window.minimized) {
    window.minimized =
      false;
  }


  if (window.fullScreen) {
    window.fullScreen =
      false;
  }


  window.setMaximize(
    false,
    false,
  );


  const previousDesktop =
    workspace.currentDesktop;

  const previousActive =
    workspace.activeWindow;


  const desktops =
    window.desktops;


  if (
    desktops &&
    desktops.length > 0 &&
    workspace.currentDesktop !==
      desktops[0]
  ) {
    workspace.currentDesktop =
      desktops[0];
  }


  workspace.activeWindow =
    window;


  if (
    !later(
      300,
      function () {
        if (
          !isManagedWindow(window)
        ) {
          restoreQuickTileContext(
            previousDesktop,
            previousActive,
          );

          finishQuickTileJob(
            job,
            false,
          );

          return;
        }


        // Reassert immediately before invoking KGlobalAccel.
        workspace.activeWindow =
          window;


        if (
          workspace.activeWindow !==
          window
        ) {
          print(
            "hakkabara-window-layout: " +
              job.target.label +
              " could not become active",
          );


          restoreQuickTileContext(
            previousDesktop,
            previousActive,
          );

          scheduleQuickTileAttempt(
            job,
          );

          return;
        }


        const shortcut =
          job.side === "left"
            ? "Window Quick Tile Left"
            : "Window Quick Tile Right";


        print(
          "hakkabara-window-layout: invoking " +
            shortcut +
            " for " +
            job.target.label,
        );


        try {
          callDBus(
            "org.kde.kglobalaccel",
            "/component/kwin",
            "org.kde.kglobalaccel.Component",
            "invokeShortcut",
            shortcut,
          );

        } catch (error) {
          print(
            "hakkabara-window-layout: KGlobalAccel call failed for " +
              job.target.label +
              ": " +
              error,
          );


          restoreQuickTileContext(
            previousDesktop,
            previousActive,
          );

          scheduleQuickTileAttempt(
            job,
          );

          return;
        }


        if (
          !later(
            900,
            function () {
              const success =
                quickTileGeometryMatches(
                  window,
                  job.side,
                );


              const geometry =
                window.frameGeometry;


              print(
                "hakkabara-window-layout: verify " +
                  job.target.label +
                  " quick-tile " +
                  job.side +
                  " -> " +
                  success +
                  " geometry=x=" +
                  geometry.x +
                  " y=" +
                  geometry.y +
                  " w=" +
                  geometry.width +
                  " h=" +
                  geometry.height,
              );


              restoreQuickTileContext(
                previousDesktop,
                previousActive,
              );


              if (success) {
                finishQuickTileJob(
                  job,
                  true,
                );

              } else {
                scheduleQuickTileAttempt(
                  job,
                );
              }
            },
          )
        ) {
          restoreQuickTileContext(
            previousDesktop,
            previousActive,
          );

          finishQuickTileJob(
            job,
            false,
          );
        }
      },
    )
  ) {
    restoreQuickTileContext(
      previousDesktop,
      previousActive,
    );

    finishQuickTileJob(
      job,
      false,
    );
  }
}


function processQuickTileQueue() {
  if (
    quickTileBusy ||
    quickTileQueue.length === 0
  ) {
    return;
  }


  const job =
    quickTileQueue.shift();


  if (
    handled[job.key] ===
    job.wanted
  ) {
    delete quickTileQueued[
      job.key
    ];

    later(
      0,
      processQuickTileQueue,
    );

    return;
  }


  quickTileBusy =
    true;


  scheduleQuickTileAttempt(
    job,
  );
}


function queueQuickTile(
  window,
  target,
  key,
  wanted,
) {
  if (
    quickTileQueued[key] ||
    handled[key] === wanted
  ) {
    return;
  }


  quickTileQueued[key] =
    true;


  quickTileQueue.push({
    window: window,
    target: target,
    side: target.quickTile,
    key: key,
    wanted: wanted,
    attempt: 0,
  });


  processQuickTileQueue();
}


function applyLayout(window) {
  const target =
    classify(window);


  if (!target) {
    return;
  }


  const key =
    windowKey(window);

  const wanted =
    signature(target);


  // Apply only once per window lifecycle.
  // Manual moving/unmaximizing afterwards remains possible.
  if (
    handled[key] === wanted
  ) {
    return;
  }


  if (
    !assignDesktop(
      window,
      target.desktop,
    )
  ) {
    return;
  }


  if (target.quickTile) {
    if (
      !quickTileGeometryMatches(
        window,
        target.quickTile,
      )
    ) {
      handled[key] =
        "pending:" +
        wanted;


      queueQuickTile(
        window,
        target,
        key,
        wanted,
      );


      return;
    }

  } else if (target.maximize) {
    if (
      !maximizeWindow(
        window,
      )
    ) {
      handled[key] =
        "pending:" +
        wanted;

      return;
    }
  }


  handled[key] =
    wanted;


  print(
    "hakkabara-window-layout: " +
      target.label +
      " -> desktop " +
      target.desktop +

      (
        target.quickTile
          ? " / quick-tile " +
            target.quickTile

          : target.maximize
            ? " / maximized"
            : ""
      ) +

      " (" +
      window.resourceClass +
      " / " +
      window.caption +
      ")",
  );
}


function watchWindow(window) {
  if (!window) {
    return;
  }


  const key =
    windowKey(window);


  if (!watched[key]) {
    watched[key] =
      true;


    const retry =
      function () {
        applyLayout(
          window,
        );
      };


    connectSignal(
      window,
      "windowClassChanged",
      retry,
    );

    connectSignal(
      window,
      "captionChanged",
      retry,
    );

    connectSignal(
      window,
      "desktopFileNameChanged",
      retry,
    );

    connectSignal(
      window,
      "minimizedChanged",
      retry,
    );

    connectSignal(
      window,
      "hiddenChanged",
      retry,
    );

    connectSignal(
      window,
      "activeChanged",
      retry,
    );

    connectSignal(
      window,
      "windowShown",
      retry,
    );
  }


  applyLayout(
    window,
  );
}


function applyExistingWindows() {
  for (
    let i = 0;
    i <
      workspace.stackingOrder.length;
    i++
  ) {
    watchWindow(
      workspace.stackingOrder[i],
    );
  }
}


// Handle windows that already exist when KWin loads the script.
applyExistingWindows();


// Handle normal manual launches and Plasma autostart.
if (
  !connectSignal(
    workspace,
    "windowAdded",

    function (window) {
      watchWindow(
        window,
      );
    },
  )
) {
  throw new Error(
    "hakkabara-window-layout: required workspace.windowAdded signal is unavailable",
  );
}


// Native Quick Tile works on the active window.
// This catches Signal/Telegram when they are opened from their tray.
connectSignal(
  workspace,
  "windowActivated",

  function (window) {
    if (window) {
      applyLayout(
        window,
      );
    }
  },
);


// Session bookkeeping only.
connectSignal(
  workspace,
  "windowRemoved",

  function (window) {
    const key =
      windowKey(window);

    delete watched[key];
    delete handled[key];
  },
);
