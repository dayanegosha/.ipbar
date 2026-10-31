# архитектура

## путь данных

`NetworkDiscovery` читает список интерфейсов через `getifaddrs`, адреса `AF_INET` и `AF_INET6`, маски и текущий link-layer MAC через `AF_LINK`. loopback исключается. адреса переводятся в текст через `getnameinfo` с `NI_NUMERICHOST`, без DNS-запросов. IPv6 scope-id сохраняется.

`SCNetworkServiceCopyAll`, `SCNetworkServiceGetInterface`, `SCNetworkInterfaceGetBSDName` и тип интерфейса связывают BSD-имена с пользовательскими сервисами. аппаратный Wi-Fi не определяется по имени `en0`. point-to-point и системные tunnel-интерфейсы распознаются отдельно.

`RouteDiscovery` использует публичный Darwin `sysctl` с `NET_RT_DUMP2`. парсер проверяет длины сообщений и sockaddr перед чтением, исключает reject/blackhole-маршруты и учитывает `RTF_IFSCOPE`. два маршрута `/1` на одном интерфейсе имеют приоритет над `/0`; одиночный маршрут split-tunnel default не заменяет. при нескольких default используется подсказка SystemConfiguration.

`NetworkInfoProvider` собирает новый независимый снимок. `State:/Network/Global/IPv4` и `IPv6` дают системный основной интерфейс, состояния сервисов — Router и DNS. шлюз из таблицы маршрутов имеет приоритет. если таблица временно недоступна, используется системный primary с предупреждением. ошибка `getifaddrs` возвращает пустой снимок с ошибкой, а не сохранённый старый адрес.

`NetworkSnapshot` выбирает интерфейс согласно настройкам. ручной выбор отсутствующего интерфейса возвращает отсутствие данных. автоматический выбор не заимствует IPv4 другого адаптера, если основной интерфейс поддерживает только IPv6. при отсутствии default route доступный локальный IPv4 всё равно показывается, со статусом локального подключения. среди адресов одного интерфейса обычный IPv4 предпочтительнее link-local.

## обновления

`NetworkMonitor` подписывается на SystemConfiguration через `SCDynamicStoreSetNotificationKeys` и `SCDynamicStoreSetDispatchQueue`, а также на `NWPathMonitor`. серия событий объединяется задержкой 150 мс. обработчик увеличивает номер поколения, а предыдущий снимок остаётся видимым до атомарной замены новым. двухсекундный таймаут не даёт показывать старый адрес бесконечно; повторные события не продлевают его. результат старого чтения не может перезаписать данные нового поколения.

чтение работает на последовательной utility-очереди. одновременно выполняется только один запрос; повторные запросы объединяются в один следующий. периодический Timer имеет tolerance и используется как дополнительная проверка; в приложении автообновление всегда включено. во время сна таймер снимается, после пробуждения данные запрашиваются заново. `stop()` отменяет NWPathMonitor, SCDynamicStore dispatch queue, debounce, таймер и наблюдателей NSWorkspace.

SwiftUI наблюдает за состоянием MainActor. NSStatusItem получает те же снимки и настройки через Combine; отдельного кэша IP у строки меню нет. NSStatusItem использует стандартную ширину по содержимому без дополнительного резерва; одинаковый текст повторно не присваивается. атомарная замена снимка устраняет прыжки при обычном обновлении. настройки и onboarding находятся в том же NSPopover, отдельных NSWindow для них нет. автоматический мониторинг не меняет сеть. переключатель Wi-Fi вызывает публичный `CWInterface.setPower` только по действию пользователя, на отдельной очереди; ошибки macOS показываются в меню. маршруты не изменяются, root не запрашивается.

## настройки и разрешения

UserDefaults хранит только настройки приложения, включая имя выбранного интерфейса. история адресов не записывается. при первом запуске сохраняется факт первой попытки включения автозапуска: ручное отключение пользователя не отменяется последующими перезапусками. автозапуск обслуживает `SMAppService.mainApp`: источником его состояния служит ServiceManagement, а не локальный флажок. ошибки и необходимость подтверждения в системных настройках показываются пользователю.

CoreWLAN читает SSID только если система позволяет это сделать. .ipbar не запрашивает Location Services и не пытается обходить ограничения приватности. `NSPasteboard` используется только по нажатию Copy. приложение не читает историю буфера.

нет аналитики, запросов публичного IP, HTTP-клиента и сторонних SDK. диагностический JSON печатается в stdout только при явном запуске с `--diagnostics`.

## публичные API

- [SystemConfiguration](https://developer.apple.com/documentation/systemconfiguration) — сервисы, состояния IPv4/IPv6/DNS и уведомления;
- [SCDynamicStoreSetDispatchQueue](https://developer.apple.com/documentation/systemconfiguration/scdynamicstoresetdispatchqueue(_:_:)) — доставка событий и отключение очереди;
- Darwin `getifaddrs`, `getnameinfo`, `sysctl`, `net/route.h` — локальные адреса и маршруты, определения из публичного macOS SDK;
- [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor) — изменения сетевого пути без внешних probes;
- [CWWiFiClient](https://developer.apple.com/documentation/corewlan/cwwificlient) — один shared-клиент CoreWLAN для доступного SSID;
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — современный запуск при входе;
- AppKit `NSStatusItem`, `NSPopover`, `NSPasteboard`, SwiftUI — нативный интерфейс.

переходы к Wi-Fi, Network и Menu Bar используют NSWorkspace и системную URL-схему `x-apple.systempreferences`. если открыть URL не удалось, открывается само приложение System Settings. название раздела скрытия значка зависит от версии macOS: Control Center на 14/15, Menu Bar на 26+. приватные настройки Control Center не читаются и не записываются.

основной popover и вкладки настроек не используют ScrollView или Form. основной экран показывает текущие значения; дополнительные IPv4, DNS и IPv6 открываются на отдельной странице по пять строк с кнопками Previous/Next. Copy All содержит весь отчёт независимо от открытой страницы.

высота popover определяется содержимым SwiftUI через `NSHostingController.sizingOptions = [.preferredContentSize]`; фиксированного запаса снизу нет. нижние действия занимают три равные колонки. строка меню использует `NSFont.menuBarFont(ofSize: 0)` — системный размер, а не подобранный вручную; параметры системных часов приложение не читает.

закрытие popover дополнено наблюдением внешних кликов через `NSEvent.addGlobalMonitorForEvents` и `applicationDidResignActive`: стандартный `.transient` не закрывается при некоторых взаимодействиях с меню и панелями. наблюдаются только нажатия кнопок мыши вне приложения, только пока popover открыт; обработчик удаляется при закрытии и завершении приложения. клавиатурные события не наблюдаются, дополнительные разрешения не запрашиваются. [ограничения transient](https://developer.apple.com/documentation/appkit/nspopover/behavior-swift.enum/transient), [наблюдение событий AppKit](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html).
