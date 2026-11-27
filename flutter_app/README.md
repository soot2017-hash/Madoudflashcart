# Madoud Flash Cards — Flutter UI

ریفکتور رابط کاربری فلش‌کارت به‌صورت ماژولار با تم بنفش، مطابق مشخصات درخواست‌شده.

> **نکته:** این پوشه سورس‌کد Flutter است و در محیط ساخت فعلی (بدون Flutter SDK)
> کامپایل نشده؛ برای ساخت APK کافی است `flutter create .` را داخل همین پوشه
> اجرا کنید و سپس `flutter build apk`.

## ساختار

```
lib/
├── main.dart                        # ریشه اپ + اعمال تم بنفش (روشن/تاریک)
├── theme/app_theme.dart             # پالت بنفش + ThemeData سفارشی
├── models/flashcard_models.dart     # FlashcardItem / WordSense (immutable) + نمونه "load"
└── widgets/
    ├── flashcard_screen.dart        # صفحه‌ی میزبان + onCreateCardFromWord
    ├── flashcard_view.dart          # هدر، بج POS، سوییچر معنی "1 / 2"، TTS
    ├── grammar_tag_row.dart         # ردیف تگ‌های دستوری (Transitive/Intransitive)
    ├── sense_body.dart              # بدنه‌ی معنی: LTR، مثال ایتالیک + TTS، "ترجمه مثال"
    ├── synonym_antonym_section.dart # مترادف/متضاد مخصوص همان معنی
    └── word_selection_area.dart     # انتخاب کلمه + قرص شناور "کارت شو" (OverlayPortal)
```

## ویژگی‌های کلیدی

- **تم بنفش** (`#6D4DC4`) با حالت روشن و تاریک
- **TTS**: `flutter_tts` با `en-US`، سرعت 0.5، توقف هنگام تعویض معنی و `dispose` کامل
- **سوییچر معنی**: فقط معنی فعال نمایش داده می‌شود
- **مترادف/متضاد مخصوص هر معنی**: برای فعل «load»: `pack, fill, load up` / `install, insert`
- **انتخاب کلمه**: قرص شناور بنفش بالای کلمه انتخاب‌شده، محدود به داخل صفحه،
  حذف علائم نگارشی (`loading up,` → `loading up`)، بسته‌شدن خودکار با اسکرول/تپ بیرون/لغو انتخاب
