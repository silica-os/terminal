// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Terminale';

  @override
  String windowTitle(String title, int columns, int rows) {
    return '$title — $columns×$rows';
  }

  @override
  String get newTab => 'Nuovo pannello';

  @override
  String get closeTab => 'Chiudi pannello';

  @override
  String get closeTabConfirmTitle =>
      'Vuoi terminare i processi in esecuzione in questo pannello?';

  @override
  String get closeTabConfirmMessage =>
      'Chiudendo questo pannello verranno terminati i processi in esecuzione.';

  @override
  String get closeWindowConfirmTitle =>
      'Vuoi terminare i processi in esecuzione in questa finestra?';

  @override
  String get closeWindowConfirmMessage =>
      'Chiudendo questa finestra verranno terminati i processi in esecuzione.';

  @override
  String get terminate => 'Termina';

  @override
  String get cancel => 'Annulla';

  @override
  String get noPty =>
      'Il terminale ha bisogno della scrivania di Silica: qui il suo servizio di pseudo-terminale non c\'è.';

  @override
  String spawnFailed(String error) {
    return 'Impossibile avviare la shell: $error';
  }

  @override
  String processExited(int code) {
    return 'Il processo è terminato con il codice $code.';
  }

  @override
  String processKilled(int signal) {
    return 'Il processo è stato chiuso dal segnale $signal.';
  }

  @override
  String get find => 'Cerca';

  @override
  String findMatches(int current, int count) {
    return '$current di $count';
  }

  @override
  String get findNoMatches => 'Nessun risultato';

  @override
  String get findPrevious => 'Risultato precedente';

  @override
  String get findNext => 'Risultato successivo';

  @override
  String get findDone => 'Fine';

  @override
  String get menuShell => 'Shell';

  @override
  String get menuEdit => 'Modifica';

  @override
  String get menuView => 'Vista';

  @override
  String get menuWindow => 'Finestra';

  @override
  String get menuHelp => 'Aiuto';

  @override
  String get secureKeyboardEntry => 'Input da tastiera sicuro';

  @override
  String get newWindow => 'Nuova finestra';

  @override
  String newWindowWithProfile(String profile) {
    return 'Nuova finestra con profilo - $profile';
  }

  @override
  String get newWindowSameCommand => 'Nuova finestra con lo stesso comando';

  @override
  String newTabWithProfile(String profile) {
    return 'Nuovo pannello con profilo - $profile';
  }

  @override
  String get newTabSameCommand => 'Nuovo pannello con lo stesso comando';

  @override
  String get newCommand => 'Nuovo comando…';

  @override
  String get newRemoteConnection => 'Nuova connessione remota…';

  @override
  String get open => 'Apri…';

  @override
  String get closeWindow => 'Chiudi finestra';

  @override
  String get closeAll => 'Chiudi tutto';

  @override
  String get useSettingsAsDefault => 'Utilizza impostazioni come default';

  @override
  String get exportSettings => 'Esporta impostazioni…';

  @override
  String get exportText => 'Esporta testo con il nome…';

  @override
  String get exportSelectedText => 'Esporta testo selezionato con il nome…';

  @override
  String get showInspector => 'Mostra inspector';

  @override
  String get editTitle => 'Modifica titolo';

  @override
  String get editBackgroundColor => 'Modifica colore di sfondo';

  @override
  String get reset => 'Ripristina';

  @override
  String get hardReset => 'Ripristino forzato';

  @override
  String get printSelection => 'Stampa selezione…';

  @override
  String get print => 'Stampa…';

  @override
  String get copySpecial => 'Copia speciale';

  @override
  String get copyWithoutBackground => 'Copia senza colore di sfondo';

  @override
  String get copyTextOnly => 'Copia solo testo';

  @override
  String get copyStyle => 'Stile per il comando Copia';

  @override
  String get terminalSettingsDefault => 'Impostazioni Terminale (default)';

  @override
  String get plainText => 'Solo testo';

  @override
  String get pasteEscaped => 'Incolla testo con caratteri di escape';

  @override
  String get pasteSelection => 'Incolla selezione';

  @override
  String get pasteSelectionEscaped =>
      'Incolla selezione con caratteri di escape';

  @override
  String get selectBetweenMarks => 'Seleziona tra i contrassegni';

  @override
  String get marks => 'Contrassegni';

  @override
  String get autoMarkPrompts => 'Contrassegna automaticamente righe di prompt';

  @override
  String get markLineAndNewline => 'Contrassegna linea e vai a capo';

  @override
  String get newlineWithoutMark => 'Vai a capo senza contrassegnare';

  @override
  String get mark => 'Contrassegna';

  @override
  String get markAsBookmark => 'Contrassegna come segnalibro';

  @override
  String get removeMark => 'Rimuovi contrassegno';

  @override
  String get bookmarks => 'Segnalibri';

  @override
  String get insertBookmark => 'Inserisci segnalibro';

  @override
  String get insertNamedBookmark => 'Inserisci segnalibro con nome…';

  @override
  String get noBookmarks => 'Nessun segnalibro';

  @override
  String get navigate => 'Naviga';

  @override
  String get previousMark => 'Vai al contrassegno precedente';

  @override
  String get selectToPreviousMark =>
      'Seleziona fino al contrassegno precedente';

  @override
  String get nextMark => 'Vai al contrassegno successivo';

  @override
  String get selectToNextMark => 'Seleziona fino al contrassegno successivo';

  @override
  String get previousBookmark => 'Vai al segnalibro precedente';

  @override
  String get selectToPreviousBookmark =>
      'Seleziona fino al segnalibro precedente';

  @override
  String get nextBookmark => 'Vai al segnalibro successivo';

  @override
  String get selectToNextBookmark => 'Seleziona fino al segnalibro successivo';

  @override
  String get clearToPreviousMark => 'Cancella fino al contrassegno precedente';

  @override
  String get clearToPreviousBookmark =>
      'Cancella fino al segnalibro precedente';

  @override
  String get clearToStart => 'Cancella fino all’inizio';

  @override
  String get removeExcessLines => 'Elimina linee in eccesso';

  @override
  String get clearScreen => 'Cancella schermata';

  @override
  String get fillScreen => 'Riempi schermo';

  @override
  String get findEllipsis => 'Trova…';

  @override
  String get findNextItem => 'Trova successivo';

  @override
  String get findPreviousItem => 'Trova precedente';

  @override
  String get findSelectAll => 'Seleziona tutto';

  @override
  String get findSelectAllInSelection => 'Seleziona tutto nella selezione';

  @override
  String get hideFindBar => 'Nascondi barra di ricerca';

  @override
  String get useSelectionForFind => 'Usa selezione per trovare';

  @override
  String get jumpToSelection => 'Vai alla selezione';

  @override
  String get showColors => 'Mostra colori';

  @override
  String get optionAsMeta => 'Usa il tasto Opzione come tasto Meta';

  @override
  String get numLock => 'Bloc Num';

  @override
  String get showAllTabs => 'Mostra tutti i pannelli';

  @override
  String get showTabBar => 'Mostra barra dei pannelli';

  @override
  String get hideMarks => 'Nascondi contrassegni';

  @override
  String get showAlternateScreen => 'Mostra schermo alternativo';

  @override
  String get hideAlternateScreen => 'Nascondi schermo alternativo';

  @override
  String get allowMouseReporting => 'Consenti resoconto mouse';

  @override
  String get splitPane => 'Dividi pannello';

  @override
  String get closeSplitPane => 'Chiudi Dividi pannello';

  @override
  String get defaultFontSize => 'Dimensioni font di default';

  @override
  String get fontBigger => 'Aumenta';

  @override
  String get fontSmaller => 'Riduci';

  @override
  String get scrollToTop => 'Scorri fino in cima';

  @override
  String get scrollToBottom => 'Scorri fino in fondo';

  @override
  String get pageUp => 'Inizio pagina';

  @override
  String get pageDown => 'Fine pagina';

  @override
  String get lineUp => 'Linea superiore';

  @override
  String get lineDown => 'Linea inferiore';

  @override
  String get showPreviousTab => 'Mostra pannello precedente';

  @override
  String get showNextTab => 'Mostra pannello successivo';

  @override
  String get moveTabToNewWindow => 'Sposta pannello in una nuova finestra';

  @override
  String get mergeAllWindows => 'Unisci tutte le finestre';

  @override
  String get openWindowGroup => 'Apri gruppo finestre';

  @override
  String get noWindowGroups => 'Nessun gruppo di finestre';

  @override
  String get saveWindowsAsGroup => 'Salva finestre come gruppo…';

  @override
  String get openManPage => 'Apri la pagina man per la selezione';

  @override
  String get searchManIndex => 'Cerca indice pagina man per selezione';

  @override
  String aboutMessage(String version) {
    return 'Versione $version. Il terminale di Silica. Software libero con licenze MIT e Apache 2.0.';
  }

  @override
  String get askAlways => 'Sempre';

  @override
  String get askNever => 'Mai';

  @override
  String get askRunning => 'Solo se ci sono processi oltre alla shell di login';

  @override
  String bellNotification(String title) {
    return '$title ha suonato il campanello.';
  }

  @override
  String get commandPlaceholder => 'Comando';

  @override
  String get connect => 'Connetti';

  @override
  String get copy => 'Copia';

  @override
  String get paste => 'Incolla';

  @override
  String get selectAll => 'Seleziona tutto';

  @override
  String get cursorBar => 'Barra';

  @override
  String get cursorBlock => 'Blocco';

  @override
  String get cursorUnderline => 'Sottolineato';

  @override
  String get editTitleMessage =>
      'Il titolo sostituisce quello impostato dal programma, per questo pannello.';

  @override
  String get exitClose => 'Chiudi la finestra';

  @override
  String get exitCloseIfClean => 'Chiudi se la shell è uscita senza errori';

  @override
  String get exitKeep => 'Non chiudere';

  @override
  String get groupNamePlaceholder => 'Nome del gruppo';

  @override
  String get hideTabBar => 'Nascondi barra dei pannelli';

  @override
  String get inspectorCommand => 'Comando';

  @override
  String get inspectorDirectory => 'Cartella';

  @override
  String get inspectorLoginShell => 'La shell di login';

  @override
  String get inspectorNotStarted => 'Non in esecuzione';

  @override
  String get inspectorProfile => 'Profilo';

  @override
  String get inspectorRunning => 'In esecuzione';

  @override
  String get inspectorSize => 'Dimensione';

  @override
  String get inspectorStatus => 'Stato';

  @override
  String get inspectorTitle => 'Ispettore';

  @override
  String get inspectorTitleRow => 'Titolo';

  @override
  String get inspectorUnknown => 'Sconosciuta';

  @override
  String get newCommandMessage =>
      'Il comando viene eseguito in una nuova finestra.';

  @override
  String get newRemoteMessage =>
      'Un host, utente@host o un indirizzo ssh://. La connessione si apre in una nuova finestra.';

  @override
  String get ok => 'OK';

  @override
  String get profileAdvanced => 'Avanzate';

  @override
  String get profileAskBeforeClosing => 'Chiedi prima di chiudere';

  @override
  String get profileBell => 'Campanello';

  @override
  String get profileBellNotify =>
      'Notifica quando suona il campanello in un pannello in secondo piano';

  @override
  String get profileBellVisual =>
      'Fai lampeggiare la finestra per il campanello';

  @override
  String get profileBoldText => 'Usa il grassetto per il testo in grassetto';

  @override
  String get profileColumns => 'Colonne';

  @override
  String get profileCursor => 'Cursore';

  @override
  String get profileCursorBlink => 'Fai lampeggiare il cursore';

  @override
  String get profileFont => 'Carattere';

  @override
  String get profileFontSize => 'Dimensione del carattere';

  @override
  String get profileKeyboard => 'Tastiera';

  @override
  String get profileName => 'Nome';

  @override
  String get profileOptionNote =>
      'Opzione invia Escape prima del tasto, come si aspettano programmi quali Emacs e readline.';

  @override
  String get profileRows => 'Righe';

  @override
  String get profileScheme => 'Colori';

  @override
  String get profileScrollback => 'Scorrimento all\'indietro';

  @override
  String get profileScrollbackKeep => 'Conserva';

  @override
  String get profileScrollbackLines => 'Righe';

  @override
  String get profileShell => 'Shell';

  @override
  String get profileShowMarks => 'Mostra i segni dei prompt';

  @override
  String get profileStartup => 'Esegui all\'avvio';

  @override
  String get profileStartupPlaceholder => 'Un comando';

  @override
  String get profileTab => 'Pannello';

  @override
  String get profileText => 'Testo';

  @override
  String get profileTitleDirectory => 'Mostra la cartella nel titolo';

  @override
  String get profileTitleSize =>
      'Mostra la dimensione nel titolo della finestra';

  @override
  String get profileWhenExits => 'Quando la shell termina';

  @override
  String get profileWindow => 'Finestra';

  @override
  String get run => 'Esegui';

  @override
  String get save => 'Salva';

  @override
  String get saveGroupMessage =>
      'Le finestre aperte e i loro pannelli vengono salvati con questo nome.';

  @override
  String get schemeDefault => 'Predefinito (segue l\'aspetto)';

  @override
  String get scrollbackLimited => 'Limitato';

  @override
  String get scrollbackUnlimited => 'Illimitato';

  @override
  String get serverPlaceholder => 'Server';

  @override
  String get settingsAutoMark => 'Segna i prompt automaticamente';

  @override
  String get settingsClipboard => 'Appunti';

  @override
  String get settingsClipboardNote =>
      'I programmi lo chiedono con la sequenza di escape OSC 52. La lettura resta disattivata se non la consenti.';

  @override
  String get settingsClipboardRead =>
      'Consenti ai programmi di leggere gli appunti';

  @override
  String get settingsClipboardWrite =>
      'Consenti ai programmi di scrivere negli appunti';

  @override
  String settingsCopyName(String name) {
    return 'Copia di $name';
  }

  @override
  String settingsDefaultMark(String name) {
    return '$name (predefinito)';
  }

  @override
  String get settingsDefaultProfile => 'Profilo predefinito';

  @override
  String get settingsDuplicate => 'Duplica';

  @override
  String get settingsEncodings => 'Codifiche';

  @override
  String get settingsEncodingsNote =>
      'Terminale parla Unicode (UTF-8) con i programmi. Le altre codifiche non sono disponibili.';

  @override
  String get settingsGeneral => 'Generale';

  @override
  String settingsGroupSummary(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count finestre',
      one: '1 finestra',
    );
    return '$name — $_temp0';
  }

  @override
  String get settingsHome => 'La cartella Home';

  @override
  String get settingsMouseReporting =>
      'Invia gli eventi del mouse ai programmi che li richiedono';

  @override
  String get settingsNewTabs => 'I nuovi pannelli si aprono in';

  @override
  String get settingsNewWindows => 'Le nuove finestre si aprono in';

  @override
  String get settingsNoGroups =>
      'Nessun gruppo di finestre. Usa Finestra › Salva finestre come gruppo per crearne uno.';

  @override
  String get settingsOpenLinks => 'Comando-clic apre i collegamenti';

  @override
  String get settingsProfiles => 'Profili';

  @override
  String get settingsRemove => 'Rimuovi';

  @override
  String get settingsSameDirectory => 'La cartella del pannello corrente';

  @override
  String get settingsTitle => 'Impostazioni di Terminale';

  @override
  String get settingsWindowGroups => 'Gruppi di finestre';

  @override
  String get showMarks => 'Mostra i segni';
}
