# 🧟 WSR_Zombie Arena v1.0 — AFK Farm

Специализированный скрипт автоматизации для режима **Zombie Arena** в Roblox (Anime Adventures). Этот скрипт полностью берет на себя процесс запуска игры из главного хаба, прохождения волн арены и автоматического перезапуска.

---

## 🚀 Основные возможности

1. **Полный цикл автоматизации хаба (`Hub Cycle`)**:
   * Самостоятельный поиск и клик по кнопке `Play` в главном хабе.
   * Умное сканирование пространства лобби: бот находит свободные ячейки (`0/4`) слева или справа от персонажа и забегает в них (зажатием клавиш `W+A` или `W+D` на 3 секунды).
   * Автоматическая настройка создаваемого матча в лобби (выбор карты, сложности и соло-лимита на 1 игрока) и клик по кнопке `CREATE`.

2. **Боевой цикл (`Combat Cycle`)**:
   * **Автоприцеливание и стрельба:** Поиск противников (зомби) на экране по цвету тела и автоматическое зажимание ЛКМ.
   * **Использование способностей:** Автоматический спам клавиш способностей (`Q`, `E`, `R`) по настраиваемым таймерам.
   * **Интеллектуальная камера:** Автоматический зум назад и наклон камеры вниз при старте раунда для максимального угла обзора.

3. **Защита от дисконнектов (`Auto-Reconnect`)**:
   * Сканирование экрана на наличие ошибки соединения (Error Code: 277/278).
   * Автоматический клик по кнопке `Reconnect`, выжидание 15 секунд для прогрузки и запуск цикла хаба с нуля.

4. **Высокая точность и стабильность**:
   * Использование системной библиотеки распознавания текста **Windows UWP OCR**.
   * Клиент-ориентированные координаты (`CoordMode Mouse Client`) и сканирование только внутренней области игры (`onlyClientArea`). Это делает работу кликов абсолютно независимой от рамок окна, разрешения экрана и положения Roblox.

---

## ⌨️ Горячие клавиши

* **`F1`** — Выравнивание и позиционирование окна Roblox под стандартный размер бота.
* **`F2`** — Запуск автоматического автофарма (можно нажимать как в главном хабе, так и внутри запущенной игры).
* **`F3`** — Экстренная остановка бота + **мгновенная перезагрузка скрипта** в оперативной памяти (для применения любых изменений).

---

## ⚙️ Настройка, запуск и активация

### 🔑 Инструкция по первой активации (для покупателей):
1. **Получите ключ:** При покупке скрипта вы получаете архив с файлами и ваш персональный **16-значный лицензионный ключ** (в формате `XXXX-XXXX-XXXX-XXXX`).
2. **Первый запуск:** Распакуйте архив в любую папку и запустите файл **`ZombieArena_Main.ahk`** (или скомпилированный `.exe`).
3. **Ввод ключа:** Скрипт автоматически определит, что это первый запуск, скопирует ваш уникальный HWID компьютера в буфер обмена и покажет окно активации.
4. **Активация:** Вставьте ваш лицензионный ключ в поле ввода и нажмите кнопку **«Активировать»**.
5. **Готово:** После успешной проверки лицензия запишется на вашем ПК (в папку `%APPDATA%\ZombieArena`). Все последующие запуски будут проходить мгновенно и без лишних окон.

### ⚙️ Выбор настроек бота:
1. В появившемся после активации GUI-интерфейсе настройте параметры фармера:
   * Выберите карту (**Map**): `Rooftop Siege` или `Atlantis`.
   * Выберите сложность (**Difficulty**): `Normal`, `Hardcore` или `Nightmare`.
   * Настройте интервалы и включение клавиш способностей (`Q`, `E`, `R`) при необходимости.
2. Нажмите кнопку **Confirm** для сохранения конфигурации.
3. Откройте окно Roblox (убедитесь, что вы находитесь в хабе или в игре).
4. Нажмите **`F2`** для старта автофарма.

---

## 📝 Логирование

Весь пошаговый лог работы бота записывается в файл:
📂 `Logs\LogFile.txt`

Если бот ведёт себя некорректно или зависает, вы всегда можете открыть этот файл и посмотреть, на каком шаге (поиск кнопки `Play`, вход в лобби, детекция волны) возникла сложность.

🧟 WSR_Zombie Arena v1.0 — Fully Autonomous AFK Farm Bot for Zombie Arena (Roblox)
Tired of grinding for hours just to get resources in Zombie Arena? Want to stack up rewards, levels, and coins while you sleep, study, or work?

WSR_Zombie Arena v1.0 is a next-generation smart macro that automates your gameplay 100%. Built on a "Set and Forget" model, it joins lobbies, adjusts settings, clears waves, collects loot, and restarts matches completely on its own!

🌟 Key Features (Explained Simply)
🏃‍♂️ Fully Automated Startup: The bot clicks Play in the hub, walks to the spaceships, finds an empty slot (0/4), and runs inside automatically.
⚙️ Auto Match Setup: Once in a lobby, the bot instantly configures your selected map, difficulty (Normal / Hardcore / Nightmare), sets the player limit to 1 (solo match), and starts the game.
🎯 Smart Combat & Aim Assist: No blind clicking! The bot detects zombie hitboxes on the screen, aims, holds down Left Click, and automatically spams your character's active skills (Q, E, R) based on customizable timers.
🔄 Auto-Reconnect (Disconnect Protection): If Roblox crashes or disconnects (Error Code 277/278), the bot automatically clicks Reconnect, waits 15 seconds for the hub to load, runs back to the lobby, and resumes farming. Your farm won't stop in the middle of the night!
📐 Pixel-Perfect Accuracy: By utilizing Windows UWP OCR (optical character recognition) and client-relative mouse coordinates, clicks never miss, regardless of window borders, screen resolution, or window positioning.
🚀 Easy to Use (No Technical Skills Required)
Open the user-friendly settings panel.
Select the Map and Difficulty you want to farm.
Launch Roblox.
Press F2 to start farming.
Press F3 to instantly stop and reload the bot.
💎 Why Choose WSR_Zombie Arena?
24/7 Stability: Extensively optimized to run for hours without freezes or memory leaks (verified by continuous testing logs of 1+ hour stable farm sessions!).
Huge Time Saver: Let the bot grind the rewards while you enjoy your real-life activities.
Friendly UI: No complex configurations or editing text files — just open the menu, select your options, and play!
Turn tedious grinding into effortless rewards with WSR_Zombie Arena v1.0!
