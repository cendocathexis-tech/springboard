# SpringBoard Widget Designer

Theos/Logos твик для **iOS 16** (rootless / Procursus). HTML-виджеты рисуются **внутри `SBIconListView`**, под иконками, а не поверх обоев. Редактор — HTML Canvas в `WKWebView`. Шрифты подключаются через `@font-face`, без установки в систему.

Пакет: `com.yourname.designer`

## Сборка

Нужны [Theos](https://theos.dev) и SDK с заголовками iOS 15+.

```sh
export THEOS=~/theos
make package
```

Debian-пакет окажется в `packages/`. Установка на устройство:

```sh
make package install
```

Или скопируйте `.deb` в Sileo / Zebra / dpkg.

После установки: **respring**.

## Установка и использование

1. Settings → Widget Designer — включите твик.
2. На домашнем экране:
   - **два пальца, long-press** — открыть редактор текущей страницы;
   - либо режим покачивания иконок → кнопка **Edit Widgets**.
3. В редакторе добавьте текст, фигуру, фото, время или заглушку погоды. Drag / resize / rotate, цвет, альфа, шрифт, z-order.
4. **Сохранить** пишет JSON текущей страницы.

## Хранение

| Что | Путь |
| --- | --- |
| Пресет страницы | `/var/mobile/Library/Preferences/com.yourname.designer/page_<N>.json` |
| Пользовательские шрифты | `.../Fonts/*.ttf` и `*.otf` |
| Картинки из редактора | `.../Images/` |
| Редактор и runtime | `/var/jb/Library/Application Support/SBWidgetDesigner/` |

Формат пресета:

```json
{
  "version": 1,
  "page": 0,
  "enabled": true,
  "elements": [
    {
      "id": "el_ab12",
      "type": "text",
      "coordSpace": "normalized",
      "x": 0.08, "y": 0.12, "w": 0.7, "h": 0.1,
      "rotation": 0,
      "z": 1,
      "font": "System",
      "fontSize": 28,
      "color": "#FFFFFF",
      "opacity": 1,
      "content": "Hello"
    }
  ]
}
```

`type`: `text` | `image` | `shape` | `datetime` | `weather`.

Координаты нормализованы относительно ячейки сетки (`SBIconListView`), поэтому виджеты сидят в сетке, а не на обоях. Слой `WKWebView` с `userInteractionEnabled = NO`, иконки остаются кликабельными. Оставляйте пустые слоты, если не хотите перекрытия с иконками.

## Шрифты

Скопируйте файлы в `Fonts/` (Filza). В редакторе откройте менеджер шрифтов: твик сканирует папку, показывает превью и подставляет `font-family` через CSS `@font-face` (base64) в WebView.

## Preferences

- список `page_*.json`
- открыть редактор (Darwin notification → SpringBoard)
- respring
- экспорт в `/var/mobile/Documents/SBWidgetDesignerExport`
- импорт JSON по абсолютному пути

## Файлы

| Файл | Роль |
| --- | --- |
| `Tweak.xm` | хуки `SBRootFolderView` / `SBIconController` |
| `SBWDManager.m` | страницы, JSON, шрифты |
| `SBWDWidgetHost.m` | runtime `WKWebView` в сетке |
| `SBWDEditorPresenter.m` | окно редактора |
| `SBWidgetDesigner.plist` | фильтр SpringBoard (Theos: имя = `TWEAK_NAME`) |
| `layout/.../editor/` | Canvas-редактор |
| `layout/.../runtime/` | отрисовка виджета |
| `prefs/` | PreferenceLoader bundle |

`Tweak.plist` в плане = `SBWidgetDesigner.plist` здесь.

## Замечания по iOS 16

Приватные селекторы SpringBoard меняются между 16.0–16.7. Если кнопка редактирования или страница не цепляются, в логе `oslog` / `syslog` смотрите `SBRootFolderView` (`currentPageIndex`, `iconListViews`) и `SBIconController setEditing:`. Погода — заглушка, без сетевого API.

Собирайте **на macOS/Linux с Theos**, не в этом Windows-каталоге напрямую, если SDK не настроен.
