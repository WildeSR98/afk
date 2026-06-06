#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
SendMode "Event"

#Include Lib\HWID.ahk
CheckLicense()

; ============================================================
;  ZombieArena_Main.ahk
;  Anime Adventures framework + Zombie Arena Farm module.
;
;  ЗАПУСК: открой этот файл в AutoHotkey v2, НЕ Main.ahk
;
;  Горячие клавиши:
;    F1 — Позиционировать Roblox
;    F2 — СТАРТ Zombie Arena Farm
;    F3 — СТОП (если работает) / перезагрузить скрипт
; ============================================================

; Загружаем весь оригинальный стек Anime Adventures
; (GameMango.ahk определяет F1/F2/F3 — мы перекроем их ниже через Hotkey())
#Include Lib\Image.ahk
#Include Lib\GUI.ahk

; ── Заглушки для переменных, которые GameMango.ahk использует внутри
;    своих функций (PlacingUnits, StoryMode и т.д.), но которые мы
;    убрали из GUI (они нам не нужны для Zombie Arena).
;    Структуры имитируют интерфейс .Text / .Value GUI-контролов.
class _StubCtrl {
    __New(t := "", v := 0) {
        this.Text  := t
        this.Value := v
    }
}
global PlacementPatternDropdown := _StubCtrl("Circle", 1)
global PriorityUpgrade          := _StubCtrl("", 0)
global StoryDropdown            := _StubCtrl("", 0)
global StoryActDropdown         := _StubCtrl("", 0)
global MatchMaking              := _StubCtrl("", 0)
global LegendDropDown           := _StubCtrl("", 0)
global LegendActDropdown        := _StubCtrl("", 0)
global RaidDropdown             := _StubCtrl("", 0)
global RaidActDropdown          := _StubCtrl("", 0)
global NextLevelBox             := _StubCtrl("", 0)
global ReturnLobbyBox           := _StubCtrl("", 0)
global AutoAbilityBox           := _StubCtrl("", 1)
global ModeDropdown             := _StubCtrl("Play", 1)
global ConfirmButton            := _StubCtrl("", 0)
global ContractPageDropdown     := _StubCtrl("", 0)
global ContractJoinDropdown     := _StubCtrl("", 0)
global InfinityCastleDropdown   := _StubCtrl("", 0)
global modeSelectionGroup       := _StubCtrl("", 0)

#Include Lib\GameMango.ahk

#Include Lib\Functions.ahk
#Include Lib\webhooksettings.ahk
#Include Lib\FindText.ahk
#Include Lib\OCR-main\Lib\OCR.ahk
#Include Lib\ZombieArenaFarm_AA.ahk

; ── Перекрываем F2 / F3 через Hotkey() API ───────────────────
; Hotkey() работает в runtime и перекрывает :: декларации
; из GameMango.ahk без конфликта при парсинге.
Hotkey "F2", (*) => ZA_Start()
Hotkey "F3", (*) => ZA_Stop()
; F1 уже задан в GameMango.ahk как moveRobloxWindow() — оставляем
