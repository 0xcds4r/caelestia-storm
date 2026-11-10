# Caelestia Storm

Мой рабочий райс на базе [caelestia-dots/shell](https://github.com/caelestia-dots/shell) —
форк системного конфига Quickshell с переделанной левой панелью и обзором воркспейсов.

![Caelestia Storm](./preview.png)

Всё, что отличается от апстрима, описано в [`LOCAL-CHANGES.md`](./LOCAL-CHANGES.md).

## Что изменено

**Бар (левая панель)**
- одна ячейка на воркспейс, вместо точки — настоящая иконка приложения (`.desktop`),
  у активного окна — свечение по силуэту иконки (`MultiEffect` shadow);
- в блоке статуса вместо caps/num и bluetooth — текущая раскладка (`ru`/`us`).

**Super / лаунчер**
- обычный поиск caelestia, а над ним сетка воркспейсов 2×5 с живыми превью окон
  (`ScreencopyView`), перетаскиванием окон между воркспейсами, навигацией стрелками,
  `Enter` и колесом мыши (страницы воркспейсов);
- справа: компактный Keep awake и Quick toggles, в которых живут ползунки громкости
  и яркости; клик по иконке динамика глушит звук (0 % / обратно);
- OSD громкости/яркости отключён — всё в лаунчере.

**Прочее**
- Keep awake переживает перезапуск шелла (`~/.local/state/caelestia/idle-inhibited`);
- Nexus → About: «Caelestia Storm», свой логотип, `v2.5.0 | STORM 1.0`;
- логотип в баре — марка Arch.

## Установка

Нужен `caelestia-shell` 2.5.0 из AUR (или совместимая версия) и `quickshell-git`.

```sh
git clone https://github.com/0xcds4r/caelestia-storm.git ~/.config/quickshell/caelestia
mkdir -p ~/.config/caelestia
cp ~/.config/quickshell/caelestia/extra/caelestia-shell.json ~/.config/caelestia/shell.json
caelestia shell -r -d
```

`extra/caelestia-shell.json` — конфиг шелла (громкость/яркость в Quick toggles,
10 воркспейсов, `osd.enabled: false` и т.д.).

## Обновление с апстрима

Форк полностью подменяет пакетный конфиг из `/etc/xdg/quickshell/caelestia`.
После обновления `caelestia-shell` нужно пересинхронизировать и заново накатить
правки — порядок описан в `LOCAL-CHANGES.md`.

## Лицензия

GPL-3.0-only, как и у апстрима (см. `LICENSE`).
