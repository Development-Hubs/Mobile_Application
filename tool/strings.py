# Source of the interface strings (English + Arabic). Run `python3 tool/strings.py` to regenerate
# lib/core/i18n/strings_en.dart and strings_ar.dart. Keep both languages for every key.
S = [
# common
("back","Back","رجوع"),("cancel","Cancel","إلغاء"),("confirm","Confirm","تأكيد"),("continue","Continue","متابعة"),("retry","Try again","حاول مرة أخرى"),
("change","Change","تغيير"),("saved","Saved","تم الحفظ"),("send","Send","إرسال"),("open","Open","فتح"),("actions","Actions","الإجراءات"),
("reason","Reason","السبب"),("loading","Loading…","جارٍ التحميل…"),("empty","Nothing here yet","لا يوجد شيء بعد"),("today","Today","اليوم"),
("previous","Previous","السابق"),("next","Next","التالي"),
("error.title","Something went wrong","حدث خطأ"),("error.generic","The request could not be completed. Try again.","تعذّر إكمال الطلب. حاول مرة أخرى."),
("error.offline","You are offline","لا يوجد اتصال"),("error.unavailable","Not available","غير متاح"),
# tabs
("tab.home","Home","الرئيسية"),("tab.help","Help","المساعدة"),("tab.inbox","Inbox","الإشعارات"),("tab.more","More","المزيد"),
# auth
("auth.footer","Secure sign-in · Your password and codes are never stored on this phone","تسجيل دخول آمن · لا تُحفظ كلمة المرور أو الرموز على هذا الهاتف"),
("auth.welcome","Welcome","أهلاً بك"),("auth.welcome_to","Welcome to {company}","أهلاً بك في {company}"),
("auth.email_hint","Staff: sign in with your work email.","الموظفون: سجّلوا الدخول ببريد العمل."),
("auth.phone_hint","Customers and workers: we will send a one-time code to your phone.","العملاء والعمال: سنرسل رمزاً لمرة واحدة إلى هاتفك."),
("auth.method_email","Work email","بريد العمل"),("auth.method_phone","Phone number","رقم الهاتف"),
("auth.company_code","Company code","رمز الشركة"),("auth.company_is","Company: {code}","الشركة: {code}"),
("auth.email","Email","البريد الإلكتروني"),("auth.password","Password","كلمة المرور"),("auth.show_password","Show password","إظهار كلمة المرور"),("auth.hide_password","Hide password","إخفاء كلمة المرور"),
("auth.mfa_title","Two-step verification","التحقق بخطوتين"),("auth.mfa_hint","Enter the 6-digit code from your authenticator app.","أدخل الرمز المكوّن من 6 أرقام من تطبيق المصادقة."),
("auth.sign_in","Sign in","تسجيل الدخول"),("auth.phone","Mobile number","رقم الجوال"),("auth.phone_helper","Qatar numbers can be written without +974","يمكن كتابة أرقام قطر بدون ‎+974"),
("auth.have_invite","I have an invitation code","لدي رمز دعوة"),("auth.invite_hint","From the office, to link your contract or file","من المكتب، لربط عقدك أو ملفك"),
("auth.invite_code","Invitation code","رمز الدعوة"),("auth.send_code","Send code","إرسال الرمز"),
("auth.enter_code","Enter the code","أدخل الرمز"),("auth.code_sent_to","We sent a code by {channel} to {phone}.","أرسلنا رمزاً عبر {channel} إلى {phone}."),
("auth.channel.sms","SMS","رسالة نصية"),("auth.channel.whatsapp","WhatsApp","واتساب"),("auth.channel.log","test log","سجل الاختبار"),("auth.channel.email","email","البريد"),
("auth.resend_in","Resend in {s}s","إعادة الإرسال خلال {s} ث"),("auth.resend","Send a new code","إرسال رمز جديد"),("auth.code_resent","A new code was sent","تم إرسال رمز جديد"),
("auth.first_time","First time here? Add your name","أول مرة؟ أضف اسمك"),("auth.your_name","Your full name","اسمك الكامل"),("auth.verify","Verify","تحقق"),
("auth.claim_pending","Thank you. The office will confirm your account soon.","شكراً لك. سيؤكد المكتب حسابك قريباً."),
# gates
("gate.update_title","Update required","يلزم التحديث"),("gate.update_body","This version is no longer supported. Install the latest version to continue.","هذا الإصدار لم يعد مدعوماً. ثبّت أحدث إصدار للمتابعة."),
("gate.maintenance_title","Down for maintenance","قيد الصيانة"),("gate.maintenance_body","The company system is being updated. Please try again shortly.","يتم تحديث نظام الشركة. حاول مرة أخرى بعد قليل."),
("gate.open_store","Open the store","فتح المتجر"),("gate.call_office","Call the office","اتصل بالمكتب"),
("connect.title","Connect to your company","الاتصال بشركتك"),("connect.body","Enter the ERP address and company code you received from your administrator.","أدخل عنوان النظام ورمز الشركة من المسؤول."),
("connect.server","ERP address","عنوان النظام"),
("workspace.title","Choose a workspace","اختر مساحة العمل"),("workspace.body","Your phone is linked to more than one company or record.","هاتفك مرتبط بأكثر من شركة أو ملف."),
("workspace.kind.customer","Customer","عميل"),("workspace.kind.worker","Worker","عامل"),("workspace.kind.staff","Staff","موظف"),("workspace.kind.pending","Awaiting link","بانتظار الربط"),
("workspace.switch","Switch workspace","تبديل مساحة العمل"),("workspace.switch_body","Lists, drafts and files of the current workspace are cleared from this phone.","سيتم مسح القوائم والمسودات والملفات الحالية من هذا الهاتف."),
("lock.title","Welcome back {name}","مرحباً بعودتك {name}"),("lock.body","Unlock with your phone's fingerprint or face recognition.","افتح القفل ببصمة الهاتف أو التعرف على الوجه."),
("lock.unlock","Unlock","فتح القفل"),("lock.use_password","Sign in with password instead","تسجيل الدخول بكلمة المرور بدلاً من ذلك"),("lock.reason","Unlock OneSource Connect","افتح OneSource Connect"),
("pending.title","Link your record","اربط ملفك"),("pending.body","Enter the invitation code from the office to see your contract, documents and services.","أدخل رمز الدعوة من المكتب لعرض عقدك ومستنداتك وخدماتك."),
("pending.link","Link","ربط"),("pending.check","Check again","تحقق مرة أخرى"),
# home
("home.morning","Good morning","صباح الخير"),("home.afternoon","Good afternoon","مساء الخير"),("home.evening","Good evening","مساء الخير"),("home.staff","Staff","موظف"),
("home.mark_attendance","Please mark your attendance","يرجى تسجيل حضورك"),("home.mark_attendance_body","You have not checked in today · shift {shift}","لم تسجّل حضورك اليوم · الوردية {shift}"),
("home.requests","{n} request(s) from your administrator","{n} طلب من المسؤول"),("home.requests_body","Open the ERP to complete them.","افتح النظام لإكمالها."),
("home.mfa","Protect your account","احمِ حسابك"),("home.mfa_body","Turn on two-step verification in the ERP profile.","فعّل التحقق بخطوتين من ملفك في النظام."),
("home.unread_notices","Unread notifications","إشعارات غير مقروءة"),("home.unread_cases","Unread case replies","ردود غير مقروءة"),
("home.your_work","Your work","عملك"),("home.all_modules","All modules","كل الوحدات"),
("home.documents","My documents","مستنداتي"),("home.days_left","{d} days left","متبقٍ {d} يوم"),("home.accommodation","My accommodation","سكني"),("home.room","Room","غرفة"),("home.bed","Bed","سرير"),
("home.trips","My trips","رحلاتي"),("home.nothing_yet","Nothing to show yet","لا يوجد ما يُعرض بعد"),("home.recruitment","Recruitment progress","سير الاستقدام"),
("home.expected","Expected","المتوقع"),("home.arrived","Arrived","وصل"),("home.pickup","Pickup","الاستقبال"),("home.placements","Placements","التشغيل"),("home.contracts","Contracts","العقود"),
("home.need_help","Need help?","تحتاج مساعدة؟"),("home.need_help_body","Ask the office; we reply here.","اسأل المكتب وسنرد هنا."),("home.ask","Ask","اسأل"),
# modules
("module.my_overview","My overview","نظرة عامة"),("module.my_overview.body","Your records at a glance","ملفاتك بنظرة سريعة"),
("module.support","Help desk","مكتب المساعدة"),("module.support.body","Cases, replies and attachments","الطلبات والردود والمرفقات"),
("module.learning","My learning","تعلّمي"),("module.learning.body","Courses, sessions and certificates","الدورات والجلسات والشهادات"),
("module.calendar","Calendar","التقويم"),("module.calendar.body","Meetings, sessions and invitations","الاجتماعات والجلسات والدعوات"),
("module.notifications","Notifications","الإشعارات"),("module.notifications.body","Everything sent to you","كل ما أُرسل إليك"),
("module.attendance","Attendance","الحضور"),("module.attendance.body","Check in, breaks and check out","الحضور والاستراحة والانصراف"),
("module.renewals","Renewals","التجديدات"),("module.renewals.body","Passports, QIDs, visas and more","الجوازات والبطاقات والتأشيرات وغيرها"),
("module.care","Care calls","مكالمات المتابعة"),("module.care.body","Follow-up calls after placement","مكالمات المتابعة بعد التشغيل"),
("module.accommodation","Bed board","لوحة الأسرّة"),("module.accommodation.body","Rooms, beds and stays","الغرف والأسرّة والإقامات"),
("module.driver","My trips","رحلاتي"),("module.driver.body","Today's itinerary and milestones","مسار اليوم والمراحل"),
("module.trainer","Training sessions","جلسات التدريب"),("module.trainer.body","Rosters and check-in codes","القوائم ورموز الحضور"),
("module.crm","CRM","إدارة العملاء"),("module.finance","Account & Finance","الحسابات والمالية"),("module.hrm","HRM","الموارد البشرية"),
("module.outside","Outside recruitment","الاستقدام الخارجي"),("module.package1","Package 1 · placement","الباقة 1 · التشغيل"),("module.package2","Package 2 · monthly","الباقة 2 · شهري"),
("module.network","Agent candidates","مرشحو الوكلاء"),("module.gm","GM module","وحدة المدير العام"),("module.chatbot","Chatbot","المساعد الآلي"),
("module.dispatch","Transport & dispatch","النقل والتوزيع"),("module.training","Training & skills","التدريب والمهارات"),("module.events","Events","الفعاليات"),
("more.group.mine","My services","خدماتي"),("more.group.me","Me","أنا"),("more.group.work","Work","العمل"),("more.group.web","In the ERP","في النظام"),
("more.web_note","Not in the app yet — opens in the browser","غير متوفر في التطبيق بعد — يفتح في المتصفح"),("more.opens_web","Opens the ERP in your browser","يفتح النظام في المتصفح"),
("more.owner","Owner","المالك"),("more.permissions","{n} permissions","{n} صلاحية"),
("more.scope.own","Own records","سجلاتي فقط"),("more.scope.team","Team records","سجلات الفريق"),("more.scope.all","All records","كل السجلات"),
# attendance
("attendance.month","Month","الشهر"),("attendance.not_linked","Not linked to a staff file","غير مرتبط بملف موظف"),("attendance.not_linked_body","Ask HR to link your user to your staff record.","اطلب من الموارد البشرية ربط حسابك بملفك الوظيفي."),
("attendance.in","Check in","تسجيل الحضور"),("attendance.out","Check out","تسجيل الانصراف"),("attendance.break_start","Start break","بدء الاستراحة"),("attendance.break_end","End break","إنهاء الاستراحة"),
("attendance.saved.in","Checked in at {time}","تم تسجيل الحضور {time}"),("attendance.saved.out","Checked out at {time}","تم تسجيل الانصراف {time}"),
("attendance.saved.break_start","Break started at {time}","بدأت الاستراحة {time}"),("attendance.saved.break_end","Break ended at {time}","انتهت الاستراحة {time}"),
("attendance.state.off","Not checked in","لم يتم تسجيل الحضور"),("attendance.state.in","Working","في العمل"),("attendance.state.break","On break","في استراحة"),("attendance.state.out","Checked out","تم الانصراف"),
("attendance.confirm_out","Check out now?","تسجيل الانصراف الآن؟"),("attendance.confirm_out_body","You worked {worked} today.","عملت اليوم {worked}."),
("attendance.worked","Worked","العمل"),("attendance.worked_today","Worked today","مدة العمل اليوم"),("attendance.on_break_for","Break time","مدة الاستراحة"),("attendance.target","Target {h}","المستهدف {h}"),
("attendance.no_actions","Nothing to record right now.","لا يوجد ما يُسجّل الآن."),("attendance.location_note","Your company records where attendance is marked.","تسجّل شركتك موقع تسجيل الحضور."),
("attendance.first_in","Check in","الحضور"),("attendance.last_out","Check out","الانصراف"),("attendance.break","Break","الاستراحة"),("attendance.shift","Shift","الوردية"),("attendance.late","Late","التأخير"),
("attendance.timeline","Today's timeline","سجل اليوم"),("attendance.timeline_empty","No punches yet today.","لا توجد تسجيلات اليوم."),
("attendance.source.web","App / web","التطبيق / الويب"),("attendance.source.device","Machine","جهاز البصمة"),("attendance.source.correction","Correction","تصحيح"),("attendance.source.mobile","App","التطبيق"),
("attendance.away","{m} m from office","{m} م من المكتب"),("attendance.fix","Corrections","التصحيحات"),("attendance.fix_body","Ask your manager to fix a day","اطلب من مديرك تصحيح يوم"),
("attendance.day_off","Today is your day off.","اليوم يوم راحتك."),("attendance.on_leave","You are on approved leave today.","أنت في إجازة معتمدة اليوم."),
("attendance.missing_out","A previous day has no check-out. Send a correction.","يوجد يوم سابق بدون انصراف. أرسل تصحيحاً."),
("attendance.month_empty","No attendance this month","لا يوجد حضور هذا الشهر"),("attendance.present","Present","حاضر"),("attendance.late_days","Late","متأخر"),("attendance.absent","Absent","غائب"),
("attendance.hours","{h} worked","{h} عمل"),("attendance.fix_this_day","Ask to fix this day","طلب تصحيح هذا اليوم"),("attendance.new_fix","New correction","تصحيح جديد"),
("attendance.no_fixes","No correction requests","لا توجد طلبات تصحيح"),("attendance.day","Day","اليوم"),("attendance.what","What needs fixing","ما المطلوب تصحيحه"),
("attendance.reason","Reason","السبب"),("attendance.send_fix","Send to manager","إرسال إلى المدير"),("attendance.fix_sent","Sent. Your manager will review it.","تم الإرسال. سيراجعه مديرك."),
("attendance.load_error","Attendance could not be loaded","تعذّر تحميل الحضور"),
# cases
("cases.new","New case","طلب جديد"),("cases.new_sub","Tell us what you need","أخبرنا بما تحتاج"),("cases.sub","Your questions and requests","أسئلتك وطلباتك"),("cases.staff_sub","Queues assigned to you and your team","قوائم الطلبات لك ولفريقك"),
("cases.search","Search reference or subject","ابحث بالرقم أو الموضوع"),("cases.q.mine","Mine","لي"),("cases.q.unassigned","Unassigned","غير مسند"),("cases.q.overdue","Overdue","متأخر"),
("cases.q.open","Open","مفتوح"),("cases.q.all","All","الكل"),("cases.q.open_mine","Open","مفتوح"),
("cases.empty","No cases here","لا توجد طلبات"),("cases.empty_body","When you open a case, the conversation appears here.","عند فتح طلب ستظهر المحادثة هنا."),
("cases.category","Category","الفئة"),("cases.subject","Subject","الموضوع"),("cases.details","Details","التفاصيل"),("cases.send","Send case","إرسال الطلب"),
("cases.created","Case {ref} created","تم إنشاء الطلب {ref}"),("cases.similar","You already have {n} similar open case(s)","لديك {n} طلب مشابه مفتوح"),
("cases.description","Description","الوصف"),("cases.outcome","Outcome","النتيجة"),("cases.restricted","Private","خاص"),("cases.internal_note","Internal note","ملاحظة داخلية"),
("cases.reply","Reply","رد"),("cases.reply_hint","Write a reply…","اكتب رداً…"),("cases.note_hint","Only staff can see this note…","هذه الملاحظة للموظفين فقط…"),
("cases.confirm_action","The requester may be notified.","قد يتم إشعار صاحب الطلب."),("cases.outcome_hint","What was done","ما الذي تم"),("cases.reason_hint","Optional reason","سبب اختياري"),
("cases.action.assign","Assign to me","إسناد إليّ"),("cases.action.start","Start working","بدء العمل"),("cases.action.wait_requester","Wait for requester","بانتظار صاحب الطلب"),
("cases.action.wait_internal","Wait internally","بانتظار داخلي"),("cases.action.resolve","Resolve","حلّ"),("cases.action.close","Close","إغلاق"),("cases.action.cancel","Cancel case","إلغاء الطلب"),("cases.action.reopen","Reopen","إعادة فتح"),
("priority.low","Low","منخفضة"),("priority.normal","Normal","عادية"),("priority.high","High","عالية"),("priority.urgent","Urgent","عاجلة"),
("files.attach","Attach","إرفاق"),("files.photo","Photo","صورة"),("files.limits","Up to 5 files, 15 MB each","حتى 5 ملفات، 15 ميغابايت لكل ملف"),("files.too_big","Files over 15 MB were skipped","تم تجاهل الملفات الأكبر من 15 ميغابايت"),
# notifications
("notices.sub","Updates from your company","تحديثات من شركتك"),("notices.prefs","Notification settings","إعدادات الإشعارات"),("notices.read_all","Mark all read","تعليم الكل كمقروء"),
("notices.all","All","الكل"),("notices.unread","Unread","غير مقروء"),("notices.empty","You're all caught up","لا توجد إشعارات جديدة"),
("notices.push_on","Push notifications are available.","الإشعارات الفورية متاحة."),("notices.push_off","Push is not set up on the server yet; the inbox is always up to date.","الإشعارات الفورية غير مفعلة في الخادم بعد؛ صندوق الإشعارات محدّث دائماً."),
("notices.account_locked","Account notices cannot be turned off","لا يمكن إيقاف إشعارات الحساب"),
# renewals
("renewals.q.open","Open","مفتوح"),("renewals.q.mine","Mine","لي"),("renewals.q.week","This week","هذا الأسبوع"),("renewals.q.expired","Expired","منتهي"),("renewals.q.submitted","Submitted","مُقدَّم"),
("renewals.empty","No renewals in this queue","لا توجد تجديدات في هذه القائمة"),("renewals.expired_ago","Expired {d} days ago","انتهى قبل {d} يوم"),("renewals.expires_in","Expires in {d} days · {date}","ينتهي خلال {d} يوم · {date}"),
("renewals.req.passport","Passport","جواز السفر"),("renewals.req.qid","Qatar ID","البطاقة القطرية"),("renewals.req.visa","Visa","التأشيرة"),("renewals.req.medical","Medical / health card","البطاقة الصحية"),
("renewals.req.contract","Contract","العقد"),("renewals.req.certificate","Training certificate","شهادة التدريب"),("renewals.req.document","Document","مستند"),
("renewals.needs_sponsor","Needs sponsor","يحتاج الكفيل"),("renewals.expires","Expires","ينتهي"),("renewals.due","Due","الاستحقاق"),("renewals.submission","Submission reference","رقم التقديم"),
("renewals.submission_hint","Reference from the government portal","الرقم من البوابة الحكومية"),("renewals.new_expiry","New expiry date","تاريخ الانتهاء الجديد"),("renewals.final","This renewal is closed.","هذا التجديد مغلق."),
("renewals.move_to","Move to {s}?","نقل إلى {s}؟"),
# care
("care.today","Due today","مستحق اليوم"),("care.upcoming","Upcoming","القادمة"),("care.empty","No calls due","لا توجد مكالمات مستحقة"),("care.audience.customer","Customer","عميل"),("care.audience.worker","Worker","عامل"),
("care.attempts","{n} attempt(s)","{n} محاولة"),("care.call","Call {phone}","اتصال {phone}"),("care.satisfaction","How satisfied are they?","ما مدى رضاهم؟"),
("care.answer.yes","Yes","نعم"),("care.answer.partly","Partly","جزئياً"),("care.answer.no","No","لا"),("care.concerns","Concerns","المخاوف"),("care.comment","Comment","تعليق"),
("care.case_note","A low score, a 'No' or any concern opens a follow-up case automatically.","التقييم المنخفض أو 'لا' أو أي مخاوف يفتح طلب متابعة تلقائياً."),
("care.save","Save call","حفظ المكالمة"),("care.no_answer","No answer","لا يوجد رد"),("care.no_answer_hint","Optional note","ملاحظة اختيارية"),("care.case_opened","Saved — a follow-up case was opened","تم الحفظ — فُتح طلب متابعة"),
# beds
("beds.empty","No properties yet","لا توجد مساكن بعد"),("beds.free","Free","متاح"),("beds.available","Free","متاح"),("beds.reserved","Reserved","محجوز"),("beds.occupied","Occupied","مشغول"),("beds.blocked","Blocked","مغلق"),
("beds.check_in","Check in","تسجيل الدخول"),("beds.check_out","Check out","تسجيل الخروج"),("beds.web_note","Assigning and moving beds is done in the ERP.","يتم تخصيص الأسرّة ونقلها من النظام."),
# trips
("trips.empty","No trips this day","لا توجد رحلات في هذا اليوم"),("trips.tz","Times in company time ({tz})","الأوقات بتوقيت الشركة ({tz})"),("trips.passenger","Passenger","راكب"),
("trips.navigate","Navigate","الملاحة"),("trips.proof","Photo proof","إثبات بالصورة"),("trips.proof_saved","Photo saved","تم حفظ الصورة"),("trips.decline","Hand back to dispatch","إعادة إلى التوزيع"),
("trips.pin","Handover PIN","رمز التسليم"),("trips.pin_hint","Ask the customer for the PIN","اطلب الرمز من العميل"),
("trips.step.accepted","Accept trip","قبول الرحلة"),("trips.step.en_route","On my way","في الطريق"),("trips.step.arrived","Arrived","وصلت"),("trips.step.in_progress","Start trip","بدء الرحلة"),
("trips.step.completed","Complete","إكمال"),("trips.step.failed","Report a problem","الإبلاغ عن مشكلة"),
# learning
("learning.check_in","Session check-in","تسجيل حضور الجلسة"),("learning.courses","Courses","الدورات"),("learning.certificates","Certificates","الشهادات"),("learning.my_courses","My courses","دوراتي"),
("learning.none","No courses yet","لا توجد دورات بعد"),("learning.catalogue","Browse courses","تصفح الدورات"),("learning.catalogue_sub","Ask to join a course","اطلب الانضمام إلى دورة"),
("learning.catalogue_empty","No courses available","لا توجد دورات متاحة"),("learning.request","Ask to join this course?","طلب الانضمام إلى هذه الدورة؟"),("learning.requested","Request sent","تم إرسال الطلب"),("learning.join","Join","انضمام"),
("learning.no_session_now","No session is starting now","لا توجد جلسة تبدأ الآن"),("learning.code_hint","Code shown by the trainer","الرمز الذي يعرضه المدرب"),("learning.checked_in","Recorded: {s}","تم التسجيل: {s}"),
("learning.waitlist","Waiting list position {n}","الترتيب في قائمة الانتظار {n}"),("learning.withdraw","Withdraw","انسحاب"),("learning.verify","Verify code","رمز التحقق"),
("trainer.empty","No sessions","لا توجد جلسات"),("trainer.capacity","Capacity {n}","السعة {n}"),("trainer.code","Check-in code","رمز الحضور"),("trainer.code_valid","Valid for {m} minutes","صالح لمدة {m} دقيقة"),
("trainer.no_roster","No learners on this session","لا يوجد متدربون في هذه الجلسة"),("trainer.mark","Mark attendance","تسجيل الحضور"),
# calendar
("calendar.empty","Nothing scheduled","لا يوجد شيء مجدول"),("calendar.all_day","All day","طوال اليوم"),("calendar.yes","Going","سأحضر"),("calendar.maybe","Maybe","ربما"),("calendar.no","Can't go","لن أحضر"),
# settings
("settings.title","Settings","الإعدادات"),("settings.sub","Language, appearance and security","اللغة والمظهر والأمان"),("settings.appearance","Appearance","المظهر"),("settings.language","Language","اللغة"),
("settings.theme","Theme","السمة"),("settings.motion","Motion","الحركة"),("settings.motion_body","Reduce animations such as the skyline and transitions","تقليل الحركات مثل الأفق والانتقالات"),
("settings.motion.system","Follow device","حسب الجهاز"),("settings.motion.reduced","Reduced","مخففة"),("settings.motion.full","Full","كاملة"),
("settings.security","Security","الأمان"),("settings.biometrics","Unlock with biometrics","الفتح بالبصمة"),("settings.biometrics_body","Uses your phone's fingerprint or face unlock. No face image is collected by the app.","يستخدم بصمة الهاتف أو فتح الوجه. لا يجمع التطبيق صور الوجه."),
("settings.biometrics_none","This phone has no biometrics set up","لا توجد بصمة مفعّلة على هذا الهاتف"),("settings.devices","Signed-in devices","الأجهزة المسجلة"),("settings.devices_body","See and sign out other devices","عرض الأجهزة الأخرى وتسجيل خروجها"),
("settings.sign_out","Sign out","تسجيل الخروج"),("settings.sign_out_body","You will need to sign in again on this phone.","ستحتاج لتسجيل الدخول مرة أخرى على هذا الهاتف."),
("settings.sign_out_all","Sign out everywhere","تسجيل الخروج من كل الأجهزة"),("settings.sign_out_all_body","Ends every session of this account, including this phone.","ينهي كل جلسات هذا الحساب بما فيها هذا الهاتف."),
("settings.about","About","حول"),("settings.version","Version","الإصدار"),("settings.server","Server","الخادم"),("settings.environment","Environment","البيئة"),
("settings.privacy","Privacy","الخصوصية"),("settings.privacy_body","Your session key is kept in the phone's secure storage. Passwords and codes are never saved.","يُحفظ مفتاح الجلسة في التخزين الآمن للهاتف. لا تُحفظ كلمات المرور أو الرموز."),
("settings.device","Device","جهاز"),("settings.this_device","This device","هذا الجهاز"),("settings.last_used","Last used","آخر استخدام"),("settings.sign_out_device","Sign out this device","تسجيل خروج هذا الجهاز"),
]
STATUS = {
"open":("Open","مفتوح"),"new":("New","جديد"),"in_progress":("In progress","قيد التنفيذ"),"awaiting_requester":("Waiting for you","بانتظارك"),"awaiting_internal":("Waiting internally","بانتظار داخلي"),
"resolved":("Resolved","تم الحل"),"closed":("Closed","مغلق"),"cancelled":("Cancelled","ملغى"),"merged":("Merged","مدمج"),
"due":("Due","مستحق"),"waiting_documents":("Waiting documents","بانتظار المستندات"),"submitted":("Submitted","مُقدَّم"),"returned":("Returned","مُعاد"),"completed":("Completed","مكتمل"),
"rejected":("Rejected","مرفوض"),"not_needed":("Not needed","غير مطلوب"),"present":("Present","حاضر"),"late":("Late","متأخر"),"absent":("Absent","غائب"),"leave":("Leave","إجازة"),
"holiday":("Holiday","عطلة"),"weekend":("Weekend","نهاية الأسبوع"),"off":("Day off","راحة"),"pending":("Pending","قيد الانتظار"),"approved":("Approved","معتمد"),
"scheduled":("Scheduled","مجدول"),"accepted":("Accepted","مقبول"),"en_route":("On the way","في الطريق"),"arrived":("Arrived","وصل"),"failed":("Failed","فشل"),
"onboard":("On board","على متن"),"no_show":("No show","لم يحضر"),"dropped":("Dropped off","تم التوصيل"),"reserved":("Reserved","محجوز"),"checked_in":("Checked in","تم الدخول"),
"checked_out":("Checked out","تم الخروج"),"attempted":("Tried","تمت المحاولة"),"enrolled":("Enrolled","مسجل"),"waitlisted":("Waiting list","قائمة الانتظار"),"withdrawn":("Withdrawn","منسحب"),
"issued":("Issued","صادرة"),"expired":("Expired","منتهية"),"revoked":("Revoked","ملغاة"),"superseded":("Replaced","مستبدلة"),"not_recorded":("Not recorded","غير مسجل"),"excused":("Excused","معذور"),
"active":("Active","نشط"),"confirmed":("Confirmed","مؤكد"),"tentative":("Maybe","ربما"),"declined":("Declined","مرفوض"),"requested":("Requested","مطلوب"),
"in":("Working","في العمل"),"out":("Checked out","انصرف"),"break":("On break","استراحة"),"available":("Free","متاح"),"blocked":("Blocked","مغلق"),"occupied":("Occupied","مشغول"),
}
for k,(en,ar) in STATUS.items(): S.append(("status."+k,en,ar))

def dart(name, idx):
    seen=set(); out=["// GENERATED by tool/strings.py — edit that file, then run it.","// ignore_for_file: lines_longer_than_80_chars","",f"const Map<String, String> {name} = {{"]
    for row in S:
        k=row[0]
        if k in seen: raise SystemExit('duplicate key '+k)
        seen.add(k)
        v=row[idx].replace("\\","\\\\").replace("'","\\'").replace("$","\\$")
        out.append(f"  '{k}': '{v}',")
    out.append("};\n")
    return "\n".join(out)

if __name__=='__main__':
    import os
    base=os.path.join(os.path.dirname(__file__),'..','lib','core','i18n')
    open(os.path.join(base,'strings_en.dart'),'w').write(dart('stringsEn',1))
    open(os.path.join(base,'strings_ar.dart'),'w').write(dart('stringsAr',2))
    print(len(S),'keys')
