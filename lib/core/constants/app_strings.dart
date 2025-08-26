/// Centralized app strings for consistent, friendly microcopy
/// Following Newport's premium brand voice: professional yet warm
class AppStrings {
  AppStrings._();

  // AUTHENTICATION
  static const String authWelcome = 'Добро пожаловать домой!';
  static const String authSubtitle = 'Войдите в свой аккаунт Newport Resident';
  static const String phoneLabel = 'Номер телефона';
  static const String phoneHint = '+7 (XXX) XXX-XX-XX';
  static const String apartmentLabel = 'Номер квартиры';
  static const String apartmentHint = 'Например: 45';
  static const String loginButton = 'Войти';
  static const String smsCodeLabel = 'Код из SMS';
  static const String smsCodeHint = 'Введите 6-значный код';
  static const String confirmButton = 'Подтвердить';
  static const String resendCode = 'Отправить код повторно';
  static const String smsHelp = 'Мы отправили SMS с кодом подтверждения на ваш номер';
  static const String authError = 'Ошибка входа';
  static const String invalidPhone = 'Введите корректный номер телефона';
  static const String invalidCode = 'Неверный код подтверждения';

  // DASHBOARD
  static const String dashboardTitle = 'Главная';
  static const String welcomeBack = 'С возвращением';
  static const String goodMorning = 'Доброе утро';
  static const String goodAfternoon = 'Добрый день';
  static const String goodEvening = 'Добрый вечер';
  static const String accountBalance = 'Баланс лицевого счёта';
  static const String balanceGood = 'Всё в порядке';
  static const String balanceWarning = 'Требует внимания';
  static const String balanceCritical = 'Требует оплаты';
  static const String quickActions = 'Быстрые действия';
  static const String latestNews = 'Последние новости';
  static const String viewAllNews = 'Все новости';

  // NAVIGATION
  static const String tabHome = 'Главная';
  static const String tabNews = 'Новости';
  static const String tabServices = 'Услуги';
  static const String tabNotifications = 'Уведомления';
  static const String tabProfile = 'Профиль';

  // NEWS
  static const String newsTitle = 'Новости';
  static const String newsEmpty = 'Пока нет новостей';
  static const String newsEmptySubtitle = 'Здесь будут появляться важные\nновости и объявления от управляющей компании';
  static const String newsUnread = 'Непрочитанные';
  static const String newsImportant = 'Важное';
  static const String newsGeneral = 'Общие';
  static const String newsReadMore = 'Читать полностью';
  static const String newsShare = 'Поделиться';
  static const String newsRefresh = 'Обновить новости';

  // SERVICES
  static const String servicesTitle = 'Услуги';
  static const String quickActionsSection = 'Быстрые действия';
  static const String bookingSection = 'Бронирование';
  static const String additionalSection = 'Дополнительные услуги';
  
  static const String serviceNewRequest = 'Подать заявку';
  static const String serviceMyRequests = 'Мои заявки';
  static const String serviceMeters = 'Счётчики';
  static const String servicePay = 'Оплатить';
  
  static const String serviceGym = 'Тренажёрный зал';
  static const String serviceConference = 'Конференц-зал';
  static const String serviceParking = 'Парковка';
  
  static const String serviceCleaning = 'Клининг';
  static const String serviceGuestPass = 'Пропуск гостя';
  static const String servicePartners = 'Партнёры';
  
  static const String servicePopular = 'Популярное';
  static const String newRequestFab = 'Новая заявка';

  // NOTIFICATIONS
  static const String notificationsTitle = 'Уведомления';
  static const String notificationsEmpty = 'Пока нет уведомлений';
  static const String notificationsEmptySubtitle = 'Здесь будут появляться ответы администратора,\nновости и системные уведомления';
  static const String notificationsMarkAllRead = 'Все';
  static const String notificationsAllRead = 'Все уведомления прочитаны';
  static const String notificationsDelete = 'Удалить уведомление?';
  static const String notificationsDeleteConfirm = 'Это действие нельзя отменить.';
  static const String notificationDeleted = 'Уведомление удалено';
  
  static const String notifFilterAll = 'Все';
  static const String notifFilterReplies = 'Ответы';
  static const String notifFilterNews = 'Новости';
  static const String notifFilterSystem = 'Система';
  
  static const String notifEmptyReplies = 'Нет ответов администратора';
  static const String notifEmptyRepliesSubtitle = 'Здесь будут отображаться ответы\nна ваши заявки и обращения';
  static const String notifEmptyNews = 'Нет новостей';
  static const String notifEmptyNewsSubtitle = 'Здесь будут появляться важные\nновости и объявления';
  static const String notifEmptySystem = 'Нет системных уведомлений';
  static const String notifEmptySystemSubtitle = 'Здесь отображаются технические\nуведомления и обновления';
  
  static const String notifToday = 'Сегодня';
  static const String notifYesterday = 'Вчера';

  // PROFILE
  static const String profileTitle = 'Профиль';
  static const String profileEdit = 'Редактировать профиль';
  static const String profilePersonal = 'Личная информация';
  static const String profileProperty = 'Недвижимость';
  static const String profileServices = 'Услуги';
  static const String profileSettings = 'Настройки';
  
  static const String profileFullName = 'ФИО';
  static const String profilePhone = 'Телефон';
  static const String profileEmail = 'Email';
  static const String profileApartment = 'Квартира';
  static const String profileBlock = 'Блок';
  static const String profileRole = 'Роль';
  static const String profileOwner = 'Собственник';
  static const String profileTenant = 'Арендатор';
  
  static const String profilePayments = 'Платежи и счета';
  static const String profileRequestHistory = 'История заявок';
  static const String profileMeterReadings = 'Показания счётчиков';
  static const String profileNotificationSettings = 'Уведомления';
  static const String profilePrivacy = 'Конфиденциальность';
  static const String profileSupport = 'Помощь и поддержка';
  static const String profileDarkTheme = 'Тёмная тема';
  
  static const String profileLogout = 'Выйти из аккаунта';
  static const String profileLogoutConfirm = 'Выйти из аккаунта?';
  static const String profileLogoutMessage = 'Вы уверены, что хотите выйти из приложения?';
  
  // PROFILE EDIT
  static const String profileEditTitle = 'Редактировать профиль';
  static const String profileEditPersonalSection = 'Личная информация';
  static const String profileEditNameLabel = 'Полное имя';
  static const String profileEditNameHint = 'Введите ваше полное имя';
  static const String profileEditEmailLabel = 'Email';
  static const String profileEditEmailHint = 'example@email.com';
  static const String profileEditSave = 'Сохранить изменения';
  static const String profileEditCancel = 'Отмена';
  static const String profileEditSuccess = 'Профиль успешно обновлен';
  static const String profileEditError = 'Ошибка при сохранении';
  static const String profileEditNameRequired = 'Пожалуйста, введите ваше имя';
  static const String profileEditEmailInvalid = 'Введите корректный email';

  // QUICK ACTIONS
  static const String quickActionsTitle = 'Быстрые действия';
  static const String quickActionNewRequest = 'Новая заявка';
  static const String quickActionPayments = 'Платежи';
  static const String quickActionMeters = 'Счётчики';
  static const String quickActionMarkAllRead = 'Прочитать все';
  static const String quickActionsTooltip = 'Быстрые действия';

  // COMMON
  static const String loading = 'Загрузка...';
  static const String error = 'Ошибка';
  static const String retry = 'Повторить';
  static const String cancel = 'Отмена';
  static const String save = 'Сохранить';
  static const String delete = 'Удалить';
  static const String edit = 'Редактировать';
  static const String close = 'Закрыть';
  static const String back = 'Назад';
  static const String next = 'Далее';
  static const String done = 'Готово';
  static const String ok = 'ОК';
  static const String yes = 'Да';
  static const String no = 'Нет';
  static const String notSpecified = 'Не указано';
  static const String comingSoon = 'Скоро появится';
  
  // ERROR MESSAGES
  static const String errorNetwork = 'Ошибка сети';
  static const String errorGeneral = 'Что-то пошло не так';
  static const String errorUnauthorized = 'Сессия истекла';
  static const String errorPageNotFound = 'Страница не найдена';
  static const String errorPageNotFoundSubtitle = 'Запрошенная страница не существует или была перемещена';
  static const String errorGoHome = 'Вернуться на главную';
  
  // SUCCESS MESSAGES
  static const String successSaved = 'Изменения сохранены';
  static const String successDeleted = 'Успешно удалено';
  static const String successSent = 'Отправлено';
  
  // VALIDATION
  static const String validationRequired = 'Обязательное поле';
  static const String validationEmail = 'Введите корректный email';
  static const String validationPhone = 'Введите корректный номер телефона';
  static const String validationMinLength = 'Минимум {length} символов';
  static const String validationMaxLength = 'Максимум {length} символов';

  // FAB TOOLTIPS
  static const String fabQuickRequest = 'Быстрая заявка';
  static const String fabNewRequest = 'Новая заявка';
  static const String fabMarkAllRead = 'Прочитать все';
  static const String fabQuickActions = 'Быстрые действия';

  // DATE/TIME
  static const String today = 'Сегодня';
  static const String yesterday = 'Вчера';
  static const String tomorrow = 'Завтра';
  
  // MONTH NAMES (for Russian localization)
  static const List<String> monthNames = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
  ];
  
  static const List<String> monthNamesShort = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  // ACCESSIBILITY
  static const String accessibilityBack = 'Назад';
  static const String accessibilityMenu = 'Меню';
  static const String accessibilityClose = 'Закрыть';
  static const String accessibilitySearch = 'Поиск';
  static const String accessibilityRefresh = 'Обновить';
  static const String accessibilitySettings = 'Настройки';

  // PLACEHOLDERS FOR FUTURE I18N
  // These will be replaced with proper localization keys when multi-language support is added
  static const String i18nPlaceholder = '[I18N]';
  
  /// Helper method to format validation messages
  static String validationMinLengthFormatted(int length) {
    return validationMinLength.replaceAll('{length}', length.toString());
  }
  
  /// Helper method to format validation messages
  static String validationMaxLengthFormatted(int length) {
    return validationMaxLength.replaceAll('{length}', length.toString());
  }
  
  /// Helper method to get formatted date
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return AppStrings.today;
    } else if (dateToCheck == yesterday) {
      return AppStrings.yesterday;
    } else {
      return '${date.day} ${monthNames[date.month - 1]}';
    }
  }
} 