#!/usr/bin/env wish
package require Tk
package require base64
# PassLite: Лёгкий менеджер паролей, минималистичный
# Автор: totiks, при поддержке xAI

set BASE_DIR [pwd]
set DB_FILE [file join $BASE_DIR passlite.db]
set BUTTON_DIR "/home/live/.config/awesome/buttons" ;# Путь для интеграции с лаунчером
set MASTER_PASS ""
set PASSWORDS [dict create]
set CONFIG_KEYS [dict create theme dark bg "#1e1e1e" fg "#ffffff" sel "#96571D" accent "#FFA500" font "Sans 11"]

# Настройка стиля
proc setup_style {} {
    global CONFIG_KEYS
    
    # Настройка глобального фона для всех окон
    option add *background [dict get $CONFIG_KEYS bg]
    option add *foreground [dict get $CONFIG_KEYS fg]
    option add *font [dict get $CONFIG_KEYS font]
    
    # Стиль для виджетов ttk с темным фоном
    ttk::style configure . -background [dict get $CONFIG_KEYS bg]
    ttk::style configure TFrame -background [dict get $CONFIG_KEYS bg]
    ttk::style configure TLabel -background [dict get $CONFIG_KEYS bg] -foreground [dict get $CONFIG_KEYS fg] -font [dict get $CONFIG_KEYS font]
    ttk::style configure TEntry -fieldbackground "#2a2a2a" -foreground [dict get $CONFIG_KEYS fg] -borderwidth 1 -background [dict get $CONFIG_KEYS bg] -selectbackground [dict get $CONFIG_KEYS sel] -selectforeground [dict get $CONFIG_KEYS fg]
    ttk::style configure TCheckbutton -background [dict get $CONFIG_KEYS bg] -foreground [dict get $CONFIG_KEYS fg] -font [dict get $CONFIG_KEYS font]
    ttk::style map TCheckbutton -background [list active [dict get $CONFIG_KEYS bg]]
    ttk::style configure TButton -background [dict get $CONFIG_KEYS sel] -foreground [dict get $CONFIG_KEYS fg] -font [dict get $CONFIG_KEYS font] -padding 3
    ttk::style map TButton -background [list active [dict get $CONFIG_KEYS accent] hover [dict get $CONFIG_KEYS accent]]
    ttk::style configure Treeview -background [dict get $CONFIG_KEYS bg] -foreground [dict get $CONFIG_KEYS fg] -fieldbackground [dict get $CONFIG_KEYS bg]
    ttk::style map Treeview -background [list selected "#96571D"] -foreground [list selected [dict get $CONFIG_KEYS fg]]
    ttk::style configure Treeview.Heading -background [dict get $CONFIG_KEYS sel] -foreground [dict get $CONFIG_KEYS fg] -font [dict get $CONFIG_KEYS font]
    ttk::style configure TScrollbar -background [dict get $CONFIG_KEYS bg] -troughcolor [dict get $CONFIG_KEYS bg] -arrowcolor [dict get $CONFIG_KEYS fg]
    
    # Настройка для обычных Tk виджетов
    . configure -background [dict get $CONFIG_KEYS bg]
}

# Создание окна с точным размером по контенту
proc create_window {w title {minwidth 0} {minheight 0}} {
    toplevel $w
    wm title $w $title
    
    # Настройка начального фона
    $w configure -background [dict get $::CONFIG_KEYS bg]
    
    # Минимизация пространства вокруг окна
    wm attributes $w -alpha 0.0
    
    # Если заданы минимальные размеры, устанавливаем их
    if {$minwidth > 0} {
        wm minsize $w $minwidth $minheight
    }
    
    # Для того, чтобы окно автоматически подстраивалось под размер UI
    wm overrideredirect $w 0
    
    return $w
}

# Подстройка размера окна под контент
proc fit_window_to_content {w {padding 2}} {
    update idletasks
    
    # Получаем геометрию внутренних элементов
    set geom [winfo reqwidth $w]x[winfo reqheight $w]
    wm geometry $w $geom
    
    # Центрируем окно
    set x [expr {([winfo screenwidth $w] - [winfo reqwidth $w]) / 2}]
    set y [expr {([winfo screenheight $w] - [winfo reqheight $w]) / 2}]
    wm geometry $w +$x+$y
    
    # Делаем окно видимым после установки геометрии
    wm attributes $w -alpha 1.0
}

# Загрузка базы
proc load_db {} {
    global DB_FILE MASTER_PASS PASSWORDS
    if {![file exists $DB_FILE]} {
        set MASTER_PASS [input_master_password "Создайте мастер-пароль"]
        return
    }
    set MASTER_PASS [input_master_password "Введите мастер-пароль"]
    set f [open $DB_FILE r]
    set data [read $f]
    close $f
    if {$data eq ""} {return}
    set decoded [base64::decode $data]
    if {[string match "*$MASTER_PASS*" $decoded]} {
        set PASSWORDS [dict create {*}[string map [list $MASTER_PASS ""] $decoded]]
    } else {
        tk_messageBox -icon error -title "Ошибка" -message "Неверный пароль!"
        set PASSWORDS [dict create]
    }
}

# Сохранение базы
proc save_db {} {
    global DB_FILE PASSWORDS MASTER_PASS
    set f [open $DB_FILE w]
    set encoded [base64::encode [concat $PASSWORDS $MASTER_PASS]]
    puts $f $encoded
    close $f
}

# Ввод мастер-пароля
proc input_master_password {title} {
    global CONFIG_KEYS
    
    # Создаем окно и фрейм с минимальными отступами
    set w [create_window .passdlg "PassLite" 200 80]
    
    ttk::frame $w.f -padding 2
    ttk::label $w.f.label -text $title
    ttk::entry $w.f.entry -show * -textvariable ::temp_pass
    ttk::button $w.f.ok -text "ОК" -command [list destroy $w]
    
    grid $w.f.label -sticky w -padx 2 -pady 2
    grid $w.f.entry -sticky ew -padx 2 -pady 2
    grid $w.f.ok -sticky ew -padx 2 -pady 2
    grid $w.f -sticky nsew
    
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1
    grid columnconfigure $w.f 0 -weight 1
    
    # Привязываем обработчик клавиши Enter
    bind $w.f.entry <Return> [list destroy $w]
    
    # Подстраиваем размер окна под контент
    fit_window_to_content $w
    
    focus -force $w.f.entry
    tkwait window $w
    return $::temp_pass
}

# Добавление пароля
proc add_password {} {
    global CONFIG_KEYS
    
    # Создаем окно и фрейм с минимальными отступами
    set w [create_window .add "PassLite: Добавить" 250 150]
    
    ttk::frame $w.f -padding 2
    set ::show_pass 0
    
    foreach field {desc login password} label {Описание Логин Пароль} {
        ttk::label $w.f.l$field -text "$label:"
        ttk::entry $w.f.$field -width 25 -show [expr {$field eq "password" ? "*" : ""}]
        grid $w.f.l$field $w.f.$field -sticky w -padx 2 -pady 1
    }
    
    ttk::checkbutton $w.f.show -text "Показать пароль" -variable ::show_pass -command {
        if {$::show_pass} {
            .add.f.password configure -show ""
        } else {
            .add.f.password configure -show *
        }
    }
    
    ttk::button $w.f.save -text "Сохранить" -command {
        set login [.add.f.login get]
        if {$login ne ""} {
            dict set ::PASSWORDS $login [list [.add.f.desc get] [.add.f.password get]]
            save_db
            tk_messageBox -icon info -title "Успех" -message "Логин сохранён!" -parent .add
            destroy .add
        }
    }
    
    grid $w.f.show - -sticky w -padx 2 -pady 1
    grid $w.f.save - -sticky e -padx 2 -pady 2
    grid $w.f -sticky nsew
    
    grid columnconfigure $w 0 -weight 1
    grid columnconfigure $w.f 1 -weight 1
    
    # Привязываем обработчик клавиши Enter
    bind $w.f.password <Return> [list $w.f.save invoke]
    
    # Подстраиваем размер окна под контент
    fit_window_to_content $w
    
    focus -force $w.f.desc
}

# Копирование пароля для логина
proc copy_password {} {
    set sel [.list.f.tree selection]
    if {$sel ne ""} {
        set login [.list.f.tree set $sel login]
        set pass [lindex [dict get $::PASSWORDS $login] 1]
        clipboard clear
        clipboard append $pass
        tk_messageBox -icon info -title "Успех" -message "Пароль для $login скопирован!" -parent .list
        destroy .list
    }
}

# Показать логины
proc list_logins {} {
    global PASSWORDS CONFIG_KEYS
    
    # Создаем окно и фрейм с минимальными отступами
    set w [create_window .list "PassLite: Логины" 320 180]
    
    ttk::frame $w.f -padding 2
    ttk::treeview $w.f.tree -columns {login desc} -show headings -selectmode browse -height 5
    $w.f.tree heading login -text "Логин"
    $w.f.tree heading desc -text "Описание"
    $w.f.tree column login -width 120
    $w.f.tree column desc -width 200
    
    dict for {login data} $PASSWORDS {
        lassign $data desc pass
        $w.f.tree insert {} end -values [list $login $desc]
    }
    
    ttk::scrollbar $w.f.sb -orient vertical -command [list $w.f.tree yview]
    $w.f.tree configure -yscrollcommand [list $w.f.sb set]
    
    ttk::button $w.f.copy_pass -text "Копировать пароль" -command copy_password
    
    grid $w.f.tree $w.f.sb -sticky nsew -padx 2 -pady 2
    grid $w.f.copy_pass - -sticky ew -padx 2 -pady 2
    grid $w.f -sticky nsew
    
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1
    grid columnconfigure $w.f 0 -weight 1
    grid rowconfigure $w.f 0 -weight 1
    
    # Привязываем обработчики событий
    bind $w.f.tree <Return> {.list.f.copy_pass invoke}
    
    # Обработка двойного клика - копирование логина в буфер и вывод сообщения
    bind $w.f.tree <Double-1> {
        set sel [%W selection]
        if {$sel ne ""} {
            # Копируем логин в буфер обмена
            set login [%W set $sel login]
            clipboard clear
            clipboard append $login
            
            # Показываем сообщение о копировании
            tk_messageBox -icon info -title "Успех" -message "Логин $login скопирован!" -parent .list
        }
    }
    
    # Подстраиваем размер окна под контент
    fit_window_to_content $w 
}

# Удаление логина
proc delete_login {} {
    global PASSWORDS CONFIG_KEYS
    
    # Создаем окно и фрейм с минимальными отступами
    set w [create_window .del "PassLite: Удалить" 320 180]
    
    ttk::frame $w.f -padding 2
    ttk::treeview $w.f.tree -columns {login desc} -show headings -selectmode browse -height 5
    $w.f.tree heading login -text "Логин"
    $w.f.tree heading desc -text "Описание"
    $w.f.tree column login -width 120
    $w.f.tree column desc -width 200
    
    dict for {login data} $PASSWORDS {
        lassign $data desc pass
        $w.f.tree insert {} end -values [list $login $desc]
    }
    
    ttk::scrollbar $w.f.sb -orient vertical -command [list $w.f.tree yview]
    $w.f.tree configure -yscrollcommand [list $w.f.sb set]
    
    ttk::button $w.f.del -text "Удалить" -command {
        set sel [.del.f.tree selection]
        if {$sel ne ""} {
            set login [.del.f.tree set $sel login]
            dict unset ::PASSWORDS $login
            save_db
            tk_messageBox -icon info -title "Успех" -message "Логин $login удалён!" -parent .del
            destroy .del
        }
    }
    
    grid $w.f.tree $w.f.sb -sticky nsew -padx 2 -pady 2
    grid $w.f.del - -sticky ew -padx 2 -pady 2
    grid $w.f -sticky nsew
    
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1
    grid columnconfigure $w.f 0 -weight 1
    grid rowconfigure $w.f 0 -weight 1
    
    # Привязываем обработчик клавиши Enter
    bind $w.f.tree <Return> [list $w.f.del invoke]
    
    # Подстраиваем размер окна под контент
    fit_window_to_content $w
}

# Главное меню
proc main_menu {} {
    global CONFIG_KEYS
    
    # Создаем окно и фрейм с минимальными отступами
    set w [create_window .menu "PassLite" 200 120]
    
    ttk::frame $w.f -padding 2
    set opts {
        "Вывести логины"
        "Добавить логин"
        "Удалить логин"
    }
    set cmds {list_logins add_password delete_login}
    
    foreach opt $opts cmd $cmds {
        ttk::button $w.f.b$cmd -text $opt -command $cmd
        grid $w.f.b$cmd -sticky ew -padx 2 -pady 1
        grid columnconfigure $w.f 0 -weight 1
    }
    
    ttk::button $w.f.exit -text "Выход" -command {destroy .menu; exit}
    grid $w.f.exit -sticky ew -padx 2 -pady 2
    grid $w.f -sticky nsew
    
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1
    
    # Подстраиваем размер окна под контент
    fit_window_to_content $w
}

# UI
setup_style

# Полностью скрываем главное (базовое) окно
wm withdraw .

# Запускаем приложение
catch {
    load_db
    main_menu
} err
if {$err ne ""} {
    tk_messageBox -icon error -title "Ошибка" -message "Ошибка: $err"
}

# Ждем закрытия всех окон
tkwait window .menu