(() => {
  "use strict";

  const prefersReducedMotion =
    window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------------------------------------------------------------
     Theme control (System / Light / Dark)
     --------------------------------------------------------------- */

  const THEME_KEY = "gridtile-theme";
  const root = document.documentElement;
  const themeToggle = document.getElementById("themeToggle");

  function applyTheme(mode) {
    if (mode === "light" || mode === "dark") {
      root.setAttribute("data-theme", mode);
    } else {
      root.removeAttribute("data-theme");
    }
    if (themeToggle) {
      themeToggle.dataset.mode = mode;
      themeToggle.setAttribute("aria-label", `Appearance: ${mode}. Activate to change.`);
    }
  }

  let currentTheme = localStorage.getItem(THEME_KEY) || "system";
  applyTheme(currentTheme);

  if (themeToggle) {
    themeToggle.addEventListener("click", () => {
      const order = ["system", "light", "dark"];
      currentTheme = order[(order.indexOf(currentTheme) + 1) % order.length];
      localStorage.setItem(THEME_KEY, currentTheme);
      applyTheme(currentTheme);
    });
  }

  /* ---------------------------------------------------------------
     Menu bar clock
     --------------------------------------------------------------- */

  const menuClock = document.getElementById("menuClock");
  function updateClock() {
    if (!menuClock) return;
    const now = new Date();
    let h = now.getHours();
    const m = String(now.getMinutes()).padStart(2, "0");
    const ampm = h >= 12 ? "PM" : "AM";
    h = h % 12 || 12;
    menuClock.textContent = `${h}:${m} ${ampm}`;
  }
  updateClock();
  window.setInterval(updateClock, 15000);

  /* ---------------------------------------------------------------
     Nav toggle (mobile)
     --------------------------------------------------------------- */

  const navToggle = document.getElementById("navToggle");
  const navMenu = document.getElementById("navMenu");

  if (navToggle && navMenu) {
    navToggle.addEventListener("click", () => {
      const isOpen = navMenu.classList.toggle("is-open");
      navToggle.setAttribute("aria-expanded", String(isOpen));
    });
    navMenu.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        navMenu.classList.remove("is-open");
        navToggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  /* ---------------------------------------------------------------
     Shared grid data for the hero demo (real, interactive)
     --------------------------------------------------------------- */

  const KEY_ROWS = [
    ["Q", "W", "E", "R", "T"],
    ["A", "S", "D", "F", "G"],
    ["Z", "X", "C", "V", "B"],
  ];
  const COLS = 5;
  const ROWS = 3;

  const KEY_POS = {};
  KEY_ROWS.forEach((rowKeys, row) => {
    rowKeys.forEach((key, col) => { KEY_POS[key] = { row, col }; });
  });

  const CODE_TO_KEY = {
    KeyQ: "Q", KeyW: "W", KeyE: "E", KeyR: "R", KeyT: "T",
    KeyA: "A", KeyS: "S", KeyD: "D", KeyF: "F", KeyG: "G",
    KeyZ: "Z", KeyX: "X", KeyC: "C", KeyV: "V", KeyB: "B",
  };

  /* Build grid overlay */
  const gridOverlay = document.getElementById("gridOverlay");
  const gridCellEls = {};

  if (gridOverlay) {
    KEY_ROWS.forEach((rowKeys, row) => {
      rowKeys.forEach((key, col) => {
        const cell = document.createElement("button");
        cell.type = "button";
        cell.className = "grid-cell";
        cell.dataset.key = key;
        cell.setAttribute("aria-label", `Grid cell ${key}`);
        const label = document.createElement("span");
        label.className = "cell-key";
        label.textContent = key;
        label.setAttribute("aria-hidden", "true");
        cell.appendChild(label);
        cell.addEventListener("click", () => pressKey(key));
        gridOverlay.appendChild(cell);
        gridCellEls[key] = cell;
      });
    });
  }

  /* Build physical-keyboard mirror (bottom of hero) */
  const keyboardEl = document.getElementById("keyboard");
  const keycapEls = {};

  if (keyboardEl) {
    KEY_ROWS.forEach((rowKeys) => {
      const rowEl = document.createElement("div");
      rowEl.className = "keyboard-row";
      rowKeys.forEach((key) => {
        const keyEl = document.createElement("button");
        keyEl.type = "button";
        keyEl.className = "key";
        keyEl.textContent = key;
        keyEl.setAttribute("aria-hidden", "true");
        keyEl.tabIndex = -1;
        keyEl.addEventListener("click", () => pressKey(key));
        rowEl.appendChild(keyEl);
        keycapEls[key] = keyEl;
      });
      keyboardEl.appendChild(rowEl);
    });
  }

  /* Build the small in-wallpaper keyboard hint (decorative, mirrors the same keys) */
  const hintKeyboardEl = document.getElementById("hintKeyboard");
  const hintKeyEls = {};
  const HINT_PULSE_KEYS = ["F"];

  if (hintKeyboardEl) {
    KEY_ROWS.forEach((rowKeys) => {
      const rowEl = document.createElement("div");
      rowEl.className = "hk-row";
      rowKeys.forEach((key) => {
        const keyEl = document.createElement("span");
        keyEl.className = "hk-key";
        keyEl.textContent = key;
        if (HINT_PULSE_KEYS.includes(key)) keyEl.classList.add("is-hint");
        rowEl.appendChild(keyEl);
        hintKeyEls[key] = keyEl;
      });
      hintKeyboardEl.appendChild(rowEl);
    });
  }

  function stopHintPulse() {
    Object.values(hintKeyEls).forEach((el) => el.classList.remove("is-hint"));
  }

  /* ---------------------------------------------------------------
     Hero demo state machine
     --------------------------------------------------------------- */

  const instructionPrimary = document.getElementById("instructionPrimary");
  const instructionSecondary = document.getElementById("instructionSecondary");
  const resetBtn = document.getElementById("demoReset");
  const activeWindowEl = document.getElementById("win-terminal");

  const TEXT_IDLE = { primary: "PRESS <em>TWO KEYS</em>", secondary: "to move this window" };
  const TEXT_SECOND = { primary: "PRESS <em>ONE MORE KEY</em>", secondary: "to finish the move" };
  const TEXT_DONE = { primary: "DONE", secondary: "Press two more keys to try again." };

  const DEFAULT_WINDOW_RECT = { x: 34, y: 20, w: 32, h: 32 };

  let state = "idle";
  let firstKey = null;
  let lockTimer = null;

  function setInstruction(t) {
    if (instructionPrimary) instructionPrimary.innerHTML = t.primary;
    if (instructionSecondary) instructionSecondary.textContent = t.secondary;
  }

  function clearHighlights() {
    Object.values(gridCellEls).forEach((el) => el.classList.remove("is-start", "is-in-rect"));
    Object.values(keycapEls).forEach((el) => el.classList.remove("is-start", "is-in-rect", "is-pressed"));
  }

  function flashPress(key) {
    const keycap = keycapEls[key];
    if (!keycap) return;
    keycap.classList.add("is-pressed");
    window.setTimeout(() => keycap.classList.remove("is-pressed"), 140);
  }

  function highlightRect(a, b) {
    const minRow = Math.min(a.row, b.row);
    const maxRow = Math.max(a.row, b.row);
    const minCol = Math.min(a.col, b.col);
    const maxCol = Math.max(a.col, b.col);
    for (let r = minRow; r <= maxRow; r += 1) {
      for (let c = minCol; c <= maxCol; c += 1) {
        const key = KEY_ROWS[r][c];
        if (gridCellEls[key]) gridCellEls[key].classList.add("is-in-rect");
        if (keycapEls[key]) keycapEls[key].classList.add("is-in-rect");
      }
    }
    return { minRow, maxRow, minCol, maxCol };
  }

  function moveActiveWindowTo(rect) {
    if (!activeWindowEl) return;
    const cellW = 100 / COLS;
    const cellH = 100 / ROWS;
    const pad = 1.3;
    const x = rect.minCol * cellW + pad;
    const y = rect.minRow * cellH + pad;
    const w = (rect.maxCol - rect.minCol + 1) * cellW - pad * 2;
    const h = (rect.maxRow - rect.minRow + 1) * cellH - pad * 2;
    activeWindowEl.style.setProperty("--x", x + "%");
    activeWindowEl.style.setProperty("--y", y + "%");
    activeWindowEl.style.setProperty("--w", w + "%");
    activeWindowEl.style.setProperty("--h", h + "%");
  }

  function resetActiveWindowPosition() {
    if (!activeWindowEl) return;
    activeWindowEl.style.setProperty("--x", DEFAULT_WINDOW_RECT.x + "%");
    activeWindowEl.style.setProperty("--y", DEFAULT_WINDOW_RECT.y + "%");
    activeWindowEl.style.setProperty("--w", DEFAULT_WINDOW_RECT.w + "%");
    activeWindowEl.style.setProperty("--h", DEFAULT_WINDOW_RECT.h + "%");
  }

  function pressKey(key) {
    if (!KEY_POS[key]) return;
    flashPress(key);
    stopHintPulse();
    if (state === "locked") return;

    if (state === "idle") {
      firstKey = key;
      state = "awaiting-second";
      clearHighlights();
      if (gridOverlay) gridOverlay.classList.add("is-visible");
      gridCellEls[key] && gridCellEls[key].classList.add("is-start");
      keycapEls[key] && keycapEls[key].classList.add("is-start");
      setInstruction(TEXT_SECOND);
      return;
    }

    if (state === "awaiting-second") {
      const a = KEY_POS[firstKey];
      const b = KEY_POS[key];
      clearHighlights();
      const rect = highlightRect(a, b);
      moveActiveWindowTo(rect);
      state = "locked";
      setInstruction(TEXT_DONE);

      const settleDelay = prefersReducedMotion ? 250 : 900;
      lockTimer = window.setTimeout(() => {
        state = "idle";
        firstKey = null;
        clearHighlights();
        if (gridOverlay) gridOverlay.classList.remove("is-visible");
        setInstruction(TEXT_IDLE);
      }, settleDelay);
    }
  }

  function resetDemo() {
    window.clearTimeout(lockTimer);
    state = "idle";
    firstKey = null;
    clearHighlights();
    if (gridOverlay) gridOverlay.classList.remove("is-visible");
    setInstruction(TEXT_IDLE);
    resetActiveWindowPosition();
  }

  if (resetBtn) resetBtn.addEventListener("click", resetDemo);

  window.addEventListener("keydown", (event) => {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    const active = document.activeElement;
    const tag = active && active.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || active?.isContentEditable) return;

    if (event.key === "Escape") {
      if (state !== "idle") { event.preventDefault(); resetDemo(); }
      return;
    }
    const key = CODE_TO_KEY[event.code];
    if (!key) return;
    event.preventDefault();
    pressKey(key);
  });

  /* ---------------------------------------------------------------
     Order-doesn't-matter mini grid examples
     --------------------------------------------------------------- */

  const miniExamplesEl = document.getElementById("miniGridExamples");
  const EXAMPLES = [
    { from: "A", to: "D" },
    { from: "F", to: "G" },
    { from: "Q", to: "B" },
  ];

  if (miniExamplesEl) {
    EXAMPLES.forEach((ex) => {
      const wrap = document.createElement("div");
      wrap.className = "mini-grid";
      const frame = document.createElement("div");
      frame.className = "mini-grid-frame";
      frame.setAttribute("role", "img");
      frame.setAttribute("aria-label", `Example rectangle from ${ex.from} to ${ex.to}`);

      const a = KEY_POS[ex.from];
      const b = KEY_POS[ex.to];
      const minRow = Math.min(a.row, b.row), maxRow = Math.max(a.row, b.row);
      const minCol = Math.min(a.col, b.col), maxCol = Math.max(a.col, b.col);

      KEY_ROWS.forEach((rowKeys, row) => {
        rowKeys.forEach((key, col) => {
          const cell = document.createElement("div");
          cell.className = "mini-grid-cell";
          if (row >= minRow && row <= maxRow && col >= minCol && col <= maxCol) cell.classList.add("is-in-rect");
          const label = document.createElement("span");
          label.className = "cell-key";
          label.textContent = key;
          cell.appendChild(label);
          frame.appendChild(cell);
        });
      });

      const caption = document.createElement("p");
      caption.className = "mini-grid-caption";
      caption.textContent = `${ex.from} → ${ex.to}`;
      wrap.appendChild(frame);
      wrap.appendChild(caption);
      miniExamplesEl.appendChild(wrap);
    });
  }

  /* ---------------------------------------------------------------
     Configuration showcase — animated, illustrative
     --------------------------------------------------------------- */

  const CONFIGS = [
    { name: "Everyday", cols: 5, rows: 3, shortcut: ["⌃", "⌥", "1"], keys: KEY_ROWS },
    { name: "Coding", cols: 4, rows: 4, shortcut: ["⌃", "⌥", "2"], keys: null },
    { name: "Ultrawide", cols: 6, rows: 2, shortcut: ["⌃", "⌥", "3"], keys: null },
  ];

  const configGrid = document.getElementById("configGrid");
  const configDims = document.getElementById("configDims");
  const configShortcut = document.getElementById("configShortcut");
  const configTabs = document.querySelectorAll(".config-tab");

  function renderConfig(index) {
    const cfg = CONFIGS[index];
    if (!configGrid) return;

    const applyContent = () => {
      configGrid.style.setProperty("--cg-cols", cfg.cols);
      configGrid.style.setProperty("--cg-rows", cfg.rows);
      configGrid.style.gridTemplateColumns = `repeat(${cfg.cols}, 1fr)`;
      configGrid.style.gridTemplateRows = `repeat(${cfg.rows}, 1fr)`;
      configGrid.innerHTML = "";
      for (let r = 0; r < cfg.rows; r += 1) {
        for (let c = 0; c < cfg.cols; c += 1) {
          const cell = document.createElement("div");
          cell.className = "cg-cell";
          if (cfg.keys && cfg.keys[r] && cfg.keys[r][c]) {
            const label = document.createElement("span");
            label.className = "cg-key";
            label.textContent = cfg.keys[r][c];
            cell.appendChild(label);
          }
          configGrid.appendChild(cell);
        }
      }
      if (configDims) configDims.textContent = `${cfg.cols} × ${cfg.rows}`;
      if (configShortcut) {
        configShortcut.innerHTML = cfg.shortcut.map((k) => `<kbd class="mini-key">${k}</kbd>`).join("");
      }
      configGrid.style.opacity = "1";
    };

    if (prefersReducedMotion) {
      applyContent();
    } else {
      configGrid.style.transition = "opacity 0.18s ease";
      configGrid.style.opacity = "0";
      window.setTimeout(applyContent, 160);
    }
  }

  configTabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      configTabs.forEach((t) => { t.classList.remove("is-selected"); t.setAttribute("aria-selected", "false"); });
      tab.classList.add("is-selected");
      tab.setAttribute("aria-selected", "true");
      renderConfig(Number(tab.dataset.config));
    });
  });

  renderConfig(0);
})();
