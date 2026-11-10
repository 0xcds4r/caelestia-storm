# Local changes to caelestia shell

Эта папка — форк `/etc/xdg/quickshell/caelestia` (скопирована 2026-11-11).
Quickshell предпочитает `~/.config/quickshell/<name>`, поэтому пакетный конфиг
из `/etc/xdg` больше не читается. После `pacman -Syu` (обновление caelestia-shell)
нужно пересинхронизировать и заново накатить правки ниже.

## 1. `modules/bar/components/workspaces/Workspace.qml`

- `hasWindows` жёстко `false` — убран второй ряд с иконками окон, ячейка на воркспейс одна.
- Удалён `Loader { id: windows }` (список иконок окон).
- Добавлены `iconToplevel` (активное окно воркспейса, иначе последнее) и `appIcon`
  (`Icons.getAppIcon(class)` — настоящая иконка приложения из .desktop).
- Добавлен `appIconComponent` (Image) и в `indicator.sourceComponent`:
  занятый воркспейс → иконка приложения, иначе shape/text/icons по `displayType`.
- Подсветка активного воркспейса — `MultiEffect` shadow (shadowScale 1.24,
  shadowColor `m3primary`) на контейнере иконки, включается только при `focused`.
  То есть обводка повторяет силуэт самой иконки, пилюля/форма её не закрывает.
- Добавлен `import QtQuick.Effects`.

## 2. `modules/bar/components/workspaces/Workspaces.qml`

В `MouseArea.onClicked` убран `Hypr.toggleSpecial("special")` — клик по уже
активному воркспейсу больше не открывает/закрывает special-воркспейс
(и не показывает его звезду). Теперь такой клик ничего не делает.

## 3. Overview воркспейсов (новый модуль)

`modules/overview/WorkspaceOverview.qml` — сетка 2×5 воркспейсов с живым превью окон
(`ScreencopyView` по Wayland-toplevel'ам), перетаскиванием окон между воркспейсами
(dispatch `hl.dsp.window.move`), кликом по окну (фокус) и по воркспейсу (переход).
Превью обрезаются по границам своей ячейки (геометрия clamp'ится в cell), скругление
сделано через `Mask` (`layer.effect`), под превью лежит чёрная подложка (и фон ячейки
чёрный, если в воркспейсе есть окна). Координаты окна считаются относительно
*usable*-области монитора (`reserved` из Hyprland), поэтому окно занимает ячейку
целиком — без выреза под бар.
Номер воркспейса рисуется только для пустых воркспейсов (`hasWindows(ws)`) — иначе он
просвечивал сквозь полупрозрачные окна (Hyprland кладёт фон в буфер toplevel'а).
Подсветка — рамка вокруг активного окна текущего воркспейса (`activeWindowAddress`
по `focusHistoryID`), радиус рамки, маски превью и подложки одинаковый
(`Tokens.rounding.large`), без анимаций.

Навигация (`modules/launcher/Content.qml` + `WorkspaceOverview.qml`):
- `←/→` — предыдущее/следующее окно, `↑/↓` — по колонкам сетки;
- `Enter` — перейти на выбранный воркспейс: если там есть окно — фокус на нём,
  иначе просто переключение воркспейса; лаунчер закрывается;
- колесо мыши — листает страницы воркспейсов (1–10, 11–20, ...);
- выделение двигается по всем ячейкам, включая пустые;
- смена воркспейса биндами (`CTRL+SUPER+←/→` и т.п.) при открытом обзоре
  сбрасывает страницу и переносит выделение на активный воркспейс;
- фокус окна (`hl.dsp.focus({ window })`) заставляет Hyprland варпить курсор в центр.
  Поэтому фокус окна и возврат курсора отправляются одним сообщением
  (`Hypr.extras.batchMessage`: `dispatch focus` + `dispatch cursor.move`) — прыжка
  не видно. Переход по воркспейсу курсор не двигает, там ничего не нужно;
- выбранное окно — сплошная рамка 3px, активное — 2px в 55% прозрачности.

`modules/launcher/Content.qml`:
- добавлен `readonly property bool showOverview: search.text.length === 0`;
- в `listWrapper` добавлен `WorkspaceOverview` (виден при пустом поиске), `ContentList`
  скрывается; размеры `listWrapper` переключаются между сеткой и списком;
- клик по воркспейсу закрывает лаунчер (`screenState.launcher = false`).

Итог: `SUPER` → обычный лаунчер caelestia (поиск снизу), пока запрос пустой — над ним
сетка воркспейсов с превью; как только начинаешь печатать — обычный список приложений.

## 4. Utilities внутри лаунчера

- `modules/overview/UtilitiesPanel.qml` (новый) — обёртка над `qs.modules.utilities.Content`
  (Screen recorder, Quick toggles) с локальными `PersistentProperties`.
- `modules/overview/KeepAwakeCard.qml` (новый) — своя карточка Keep awake с управляемой
  высотой: ей передаётся `overview.cellHeight`, чтобы она совпадала по высоте с первым
  рядом ячеек. Штатная карточка отключена (`utilities.cards.keepAwake: false` в shell.json).
- `modules/utilities/cards/Toggles.qml` — в карточку Quick toggles добавлены строки
  громкости и яркости (`StyledSlider`, колесо мыши), монитор берётся через
  `Brightness.getMonitorForScreen(screenState.modelData)`. Клик по иконке динамика
  глушит звук: `Audio.toggleMute()` запоминает громкость, ставит её в 0 и mute,
  повторный клик возвращает прежний уровень (слайдер и `%` показывают 0 %);
- `services/Audio.qml` — добавлена `toggleMute()`;
- `modules/launcher/Content.qml` — при пустом запросе `Row` на всю ширину:
  сетка воркспейсов слева, utilities справа;
- `shell.json`: `utilities.cards.recorder: false` (карточка Screen recorder убрана),
  `osd.enabled: false` — всплывающий OSD громкости/яркости отключён,
  всё управление теперь в лаунчере.
- `modules/drawers/Interactions.qml` — убрано открытие utilities по наведению в угол
  (`screenState.utilities = showUtilities` → no-op); бинд `caelestia:utilities`
  по-прежнему открывает панель отдельно.

## 5. Состояние utilities/записи не сбрасывается

- `modules/launcher/Wrapper.qml`: `Loader.active: true` — контент лаунчера больше не
  уничтожается при закрытии, поэтому наши `UtilitiesPanel`/`ControlsPanel` (и их
  локальное состояние, `Ref` для `Recorder`) живут постоянно.
- `modules/overview/WorkspaceOverview.qml`: новый флаг `live`, `ScreencopyView` захватывает
  окно только когда лаунчер открыт (`live: root.screenState.launcher`) — иначе после
  постоянной инстанциации превью крутились бы всегда.
- `services/Recorder.qml`: опрос `pidof` идёт пока `refCount > 0 || props.running`,
  то есть таймер/состояние записи не замирают, когда панель закрыта.
- `modules/overview/UtilitiesPanel.qml`: свой `reloadableId` (`overviewUtilities`),
  чтобы не перетирать `PersistentProperties` штатной utilities-панели.

## 6. Keep awake переживает рестарт шелла

`PersistentProperties` в этой версии не пишет состояние на диск (файла нет), поэтому
`IdleInhibitor` сбрасывался при каждом перезапуске шелла. Добавлен `IdleState.qml`
(инстанс в `shell.qml`): пишет `~/.local/state/caelestia/idle-inhibited` при изменении
и восстанавливает состояние на старте. В `KeepAwakeCard` обработчик `onToggled`
не пишет состояние, если оно не изменилось (защита от binding-эха).

## 7. Название в Settings → About

`modules/nexus/pages/AboutPage.qml` — заголовок hero-блока "Caelestia" → "Caelestia Storm",
`AnimatedLogo` заменён на `Image` (`assets/storm-logo.png`, 128×128, скопирован из
`~/Downloads/Crisp Thundercloud and Lavender Swirl.png`).

## 8. Dashboard только вместе с Super

- `shell.json`: `dashboard.showOnHover: false` — верхняя панель больше не раскрывается
  наведением на верхний край.
- `modules/launcher/Wrapper.qml`: `Connections` на `screenState` — `dashboard`
  включается/выключается вместе с лаунчером (`dashboard = launcher`).
- `modules/drawers/Interactions.qml`: hover-блок дашборда работает только при
  `dashboard.showOnHover` (иначе каждый mousemove гасил панель).

## 9. `~/.config/caelestia/shell.json`

`bar.workspaces.activeIndicator: false` — штатный индикатор (залитая пилюля)
отключён, иначе он перекрашивает/перекрывает иконку.

## Как обновить (после обновления пакета)

```sh
cp -a /etc/xdg/quickshell/caelestia/. ~/.config/quickshell/caelestia/
# затем заново применить пункты выше
```

Либо удалить форк целиком и вернуться к стоковому виду:
`rm -rf ~/.config/quickshell/caelestia && caelestia shell -r -d`
