Ben şuan bir fitcoaching adlı bir backend projesi yazdım bu sisteme koçlar  alanları (fitness,powerlifting,koşucu) ,gender gibi bilgiler ve cv, sertifikalarıyla kaydoluyorlar  bu ikisi zorunlu  ve kaçtane öğrenci ile çalışmak istedikleriniide giriyorlar tabi ve bekliyorlar öğrencileri  öğrenciler de giriş yspıyo gerekli bilgilerle  bu koç ve öğrenci için gerekli bilgiler iswagger api de var göremezsen sor  sonra öğrenciler beğendikleri koçlara istek atıyorlar gerekli kontrollerden geçtikten sorna istek. koçlar kabul yada reddediyor sonra başlıyorlar koç bu öğrencilere antrenman programı giriyor ve öğrenciler onu uygulamaya başlıyor fakat öğrenci antrenmanları eski antrenamnalardan kopyalanarak gelebilir yada koç her seferidne elle gircek ve öğrenciye antrenmanlar bekliyor olarak düşüyor  ve öğrenciye waiting olanen eski antrenman gösteriliyor ve onu uyguluyor öğrenci sonra onuda öğrenci giriyor yaptığı antrenmanı ve koça görüyor bunu ve sonraki antrenamnı ona göre yapıyor sonra öğrenci resim yükleyebilir tahlil yükleyebilir  diğer 2 entry de yemek ve uyku verisi koç bunları sadece bakabiliyor veya feedbackde şunları arttır diyebilir onun harici uyku verisi ve yemek verisi giremiyor buna göre bana bir frontend yaz  

senden istediklerim şunalr bu front karmaşık olmasın sade olsun ve böyle neon renkleri kullanama arka plan beyaz olsun bir örenk yükledim yapay zeka yapmış gibi gözükmesin  bu resim sadece tema için  eğer başka soru sorcaksna sor burası önemli soru sorabilirsin   






![alt text](image.png)

![alt text](image-1.png)

![alt text](image.png)


openapi: 3.0.3
info:
  title: FitCoaching API
  version: "1.0.0"
  description: |
    FitCoaching — koç/öğrenci eşleştirme, antrenman/beslenme/uyku takibi ve
    belge (tahlil/sertifika) yönetimi API'si.

    **Önemli notlar:**
    - Tüm endpoint'ler `POST` metodunu kullanıyor (GET/DELETE/PATCH kullanılmıyor),
      bu yüzden filtreleme/id bilgileri de body üzerinden gönderiliyor.
    - Yetkilendirme `Authorization: Bearer <accessToken>` header'ı ile yapılıyor.
    - Bazı endpoint'ler hata durumunda `{"error": "..."}` (basit format), bazıları
      `ResponseWrapper` formatını (`status/banner/data`) dönüyor — kodun mevcut
      haliyle tutarlı olacak şekilde, her endpoint kendi gerçek response şeklini
      referans alıyor.
    - `entities.Set` struct'ında JSON tag'i olmadığı için, set alanları PascalCase
      (`ID`, `MovementName` gibi) olarak gönderilip alınıyor — diğer endpoint'lerin
      çoğunda kullanılan `snake_case`'den farklı, bu tutarsızlık koddan geliyor.

servers:
  - url: http://localhost:8080

tags:
  - name: Auth
  - name: Relations
  - name: Workouts
  - name: Meals
  - name: Sleep
  - name: Ratings
  - name: Documents

security:
  - bearerAuth: []

paths:

  # ───────────────────────── AUTH ─────────────────────────

  /register/student:
    post:
      tags: [Auth]
      summary: Öğrenci kaydı
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [name, password, validatePassword, email, age, bodyFatPercentage, bodyWeight, bodyHeight, gender]
              properties:
                name: { type: string }
                password: { type: string }
                validatePassword: { type: string, description: "password ile birebir eşleşmeli" }
                email: { type: string, format: email }
                age: { type: integer, minimum: 11, maximum: 49 }
                bodyFatPercentage: { type: number, format: float, minimum: 1, maximum: 50 }
                bodyWeight: { type: number, format: float, minimum: 11, maximum: 199 }
                bodyHeight: { type: number, format: float, minimum: 51, maximum: 249 }
                gender: { type: string }
      responses:
        '201':
          description: Kayıt başarılı
          content:
            application/json:
              schema:
                type: object
                properties:
                  message: { type: string, example: "kayıt başarılı" }
        '400':
          description: Doğrulama hatası (email formatı, şifre kuralı, aralık dışı değer, email zaten kayıtlı vb.)
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /register/coach:
    post:
      tags: [Auth]
      summary: Koç kaydı (sertifika/CV dosyalarıyla birlikte)
      security: []
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              required: [username, password, password_confirm, email, max_students, speciality, gender]
              properties:
                username: { type: string }
                password: { type: string }
                password_confirm: { type: string }
                email: { type: string, format: email }
                max_students: { type: string, description: "sayı olarak parse edilir, 0-20 aralığında" }
                speciality: { type: string }
                gender: { type: string }
                files:
                  type: array
                  items: { type: string, format: binary }
                  description: "Sertifika/CV dosyaları — PDF, JPEG, PNG (config.MaxFileSize altında)"
      responses:
        '201':
          description: Kayıt başarılı
          content:
            application/json:
              schema:
                type: object
                properties:
                  message: { type: string, example: "Succesfully registered" }
        '400':
          description: Doğrulama hatası / dosya hatası
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /register/login:
    post:
      tags: [Auth]
      summary: Giriş yap
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [email, password]
              properties:
                email: { type: string, format: email }
                password: { type: string }
      responses:
        '200':
          description: Giriş başarılı
          content:
            application/json:
              schema:
                type: object
                properties:
                  message: { type: string }
                  accesstoken: { type: string, description: "JWT, kısa ömürlü" }
                  refreshtoken: { type: string, description: "uzun ömürlü, /refresh için kullanılır" }
                  role: { type: string }
        '400':
          description: Email/şifre geçersiz
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }
        '401':
          description: Şifre yanlış
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /refresh:
    post:
      tags: [Auth]
      summary: Refresh token ile yeni access token al
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [refreshtoken]
              properties:
                refreshtoken: { type: string }
      responses:
        '200':
          description: Yeni access token
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data: { type: string, description: "yeni access token" }
        '400':
          description: Token geçersiz/süresi dolmuş
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

  # ───────────────────────── RELATIONS ─────────────────────────

  /coaches:
    post:
      tags: [Relations]
      summary: Kapasitesi dolu olmayan koçları listele
      description: "Sadece Student rolü. Body gerekmez."
      responses:
        '200':
          description: Koç listesi
          content:
            application/json:
              schema:
                type: array
                items: { $ref: '#/components/schemas/Coach' }

  /relations/request:
    post:
      tags: [Relations]
      summary: Bir koça bağlanma isteği gönder
      description: "Sadece Student rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [coach_id]
              properties:
                coach_id: { type: integer }
      responses:
        '200':
          description: İstek gönderildi
          content:
            application/json:
              schema:
                type: object
                properties:
                  Relation: { $ref: '#/components/schemas/Relation' }
        '400':
          description: "Zaten koçu var / bekleyen isteği var / koç kapasitesi dolu"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /relations/pending:
    post:
      tags: [Relations]
      summary: Koçun bekleyen isteklerini listele
      description: "Sadece Coach rolü. Body gerekmez."
      responses:
        '200':
          description: Bekleyen istekler
          content:
            application/json:
              schema:
                type: object
                properties:
                  PendingRequests:
                    type: array
                    items: { $ref: '#/components/schemas/Relation' }

  /relations/accept:
    post:
      tags: [Relations]
      summary: Bekleyen bir isteği kabul et
      description: "Sadece Coach rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [student_id]
              properties:
                student_id: { type: integer }
      responses:
        '200':
          description: İstek kabul edildi, ilişki aktif
          content:
            application/json:
              schema:
                type: object
                properties:
                  relation: { $ref: '#/components/schemas/Relation' }
        '400':
          description: "İsteğin süresi dolmuş / kapasite dolu / kayıt bulunamadı"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

  /relations/reject:
    post:
      tags: [Relations]
      summary: Bekleyen bir isteği reddet
      description: "Sadece Coach rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [student_id]
              properties:
                student_id: { type: integer }
      responses:
        '200':
          description: İstek reddedildi
          content:
            application/json:
              schema:
                type: object
                properties:
                  relation: { type: string, example: "relation reset" }

  /relations/myStudents:
    post:
      tags: [Relations]
      summary: Koçun aktif öğrencilerini listele
      description: "Sadece Coach rolü. Body gerekmez."
      responses:
        '200':
          description: Aktif öğrenciler
          content:
            application/json:
              schema:
                type: object
                properties:
                  Students:
                    type: array
                    items: { $ref: '#/components/schemas/Relation' }

  /relations/leave:
    post:
      tags: [Relations]
      summary: Mevcut koçtan ayrıl
      description: "Sadece Student rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [coach_id]
              properties:
                coach_id: { type: integer }
      responses:
        '200':
          description: Ayrılık tamamlandı
          content:
            application/json:
              schema:
                type: object
                properties:
                  status: { type: string, example: "success" }
        '400':
          description: "Bu koçla aktif bağlantı yok"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /relations/myCoach:
    post:
      tags: [Relations]
      summary: Öğrencinin mevcut aktif koçunu getir
      description: "Sadece Student rolü. Body gerekmez."
      responses:
        '200':
          description: Aktif koç bilgisi
          content:
            application/json:
              schema:
                type: object
                properties:
                  Coach: { $ref: '#/components/schemas/Coach' }
        '400':
          description: "Aktif koç bulunamadı"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /relations/pastCoach:
    post:
      tags: [Relations]
      summary: Öğrencinin en son ayrıldığı (geçmiş) koçunu getir
      description: "Sadece Student rolü. Body gerekmez."
      responses:
        '200':
          description: Geçmiş koç bilgisi
          content:
            application/json:
              schema:
                type: object
                properties:
                  Coach: { $ref: '#/components/schemas/Coach' }
        '400':
          description: "Geçmiş koç bulunamadı veya ilişki 'breakup' değil"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

  # ───────────────────────── WORKOUTS ─────────────────────────

  /workout/workoutAdd:
    post:
      tags: [Workouts]
      summary: Koç, öğrenciye yeni bir antrenman planı girer
      description: "Sadece Coach rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/AddWorkoutInput' }
      responses:
        '200':
          description: Plan oluşturuldu
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data: { $ref: '#/components/schemas/Workout' }

  /workout/getworkout:
    post:
      tags: [Workouts]
      summary: Öğrenci, koçun girdiği güncel planı görür
      description: "Sadece Student rolü. Body gerekmez."
      responses:
        '200':
          description: Bugünkü plan
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data: { $ref: '#/components/schemas/WorkoutM' }

  /workout/saveWorkout:
    post:
      tags: [Workouts]
      summary: Öğrenci, gerçekleştirdiği antrenmanı kaydeder
      description: "Sadece Student rolü. `source_plan_id` zorunlu — hangi plana cevap verdiğini belirtir."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              allOf:
                - $ref: '#/components/schemas/AddWorkoutInput'
                - type: object
                  required: [source_plan_id, student_id]
      responses:
        '200':
          description: Kaydedildi, ilgili plan 'done' olarak işaretlendi
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data: { $ref: '#/components/schemas/Workout' }

  /workout/workoutcopy:
    post:
      tags: [Workouts]
      summary: Koç, geçmiş bir antrenmanı başka bir öğrenciye/tarihe kopyalar
      description: "Sadece Coach rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [workout_id, student_id]
              properties:
                workout_id: { type: integer, description: "kopyalanacak kaynağın id'si" }
                student_id: { type: integer, description: "hedef öğrenci" }
      responses:
        '200':
          description: Kopya oluşturuldu
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data: { $ref: '#/components/schemas/WorkoutM' }

  /workout/workoutupdate:
    post:
      tags: [Workouts]
      summary: Koç, öğrenci henüz cevaplamadan bir planı günceller
      description: "Sadece Coach rolü. Plan `waiting` durumunda değilse reddedilir."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              allOf:
                - $ref: '#/components/schemas/AddWorkoutInput'
                - type: object
                  required: [workout_id, student_id]
      responses:
        '200':
          description: Güncellendi
          content:
            application/json:
              schema:
                type: object
                properties:
                  status: { type: boolean, example: true }
                  banner: { type: string, example: "workout updated" }
        '400':
          description: "Plana sahip değil / plan zaten cevaplanmış / öğrenci koça bağlı değil"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

  /workout/workoutlist:
    post:
      tags: [Workouts]
      summary: Koçun girdiği tüm planları listele
      description: "Sadece Coach rolü. Body gerekmez."
      responses:
        '200':
          description: Plan listesi
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data:
                        type: array
                        items: { $ref: '#/components/schemas/WorkoutM' }

  /workout/workoutsbytime:
    post:
      tags: [Workouts]
      summary: Belirli bir tarih aralığındaki antrenmanları listele
      description: |
        Hem Coach hem Student erişebilir. Coach ise `student_id` zorunludur
        (kendi öğrencisi olmalı); Student ise sadece kendi verisini görür.
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [start_date, end_date]
              properties:
                start_date: { type: string, example: "2026-07-01 00:00:00", description: "format: 2006-01-02 15:04:05" }
                end_date: { type: string, example: "2026-07-31 23:59:59" }
                student_id: { type: integer, description: "sadece Coach rolünde zorunlu" }
      responses:
        '200':
          description: Antrenman listesi
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data:
                        type: array
                        items: { $ref: '#/components/schemas/WorkoutM' }

  /workout/workout:
    post:
      tags: [Workouts]
      summary: Tek bir antrenmanın detayını getir
      description: "Hem Coach hem Student erişebilir."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [workout_id, student_id]
              properties:
                workout_id: { type: integer }
                student_id: { type: integer, description: "Student rolünde de gönderilmesi gerekir" }
      responses:
        '200':
          description: Antrenman detayı
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data: { $ref: '#/components/schemas/WorkoutM' }

  # ───────────────────────── MEALS ─────────────────────────

  /meal/addMeal:
    post:
      tags: [Meals]
      summary: Öğün ekle
      description: "Sadece Student rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [meal_name, description, kcal, protein, oil]
              properties:
                meal_name: { type: string }
                description: { type: string }
                kcal: { type: number }
                protein: { type: number }
                oil: { type: number }
      responses:
        '200':
          description: Öğün eklendi
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

  /meal/dailyMeals:
    post:
      tags: [Meals]
      summary: Günlük öğün toplamını getir (kcal/protein/yağ toplamı)
      description: "Hem Coach hem Student erişebilir. Coach ise `student_id` zorunludur."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [start_date]
              properties:
                start_date: { type: string, example: "2026-07-23 00:00:00", description: "geçmiş bir tarih olmalı" }
                student_id: { type: integer, description: "sadece Coach rolünde zorunlu" }
      responses:
        '200':
          description: Günlük toplam
          content:
            application/json:
              schema:
                type: object
                properties:
                  meals: { $ref: '#/components/schemas/MealSummary' }

  /meal/getMeals:
    post:
      tags: [Meals]
      summary: Tarih aralığındaki öğünleri listele
      description: "Hem Coach hem Student erişebilir. Coach ise `student_id` zorunludur."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [start_date, end_date]
              properties:
                start_date: { type: string, example: "2026-07-01 00:00:00" }
                end_date: { type: string, example: "2026-07-31 23:59:59" }
                student_id: { type: integer, description: "sadece Coach rolünde zorunlu" }
      responses:
        '200':
          description: Öğün listesi
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data:
                        type: array
                        items: { $ref: '#/components/schemas/Meal' }

  /meal/deleteMeal:
    post:
      tags: [Meals]
      summary: Bir öğünü sil
      description: "Sadece Student rolü, sadece kendi öğünü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [meal_id]
              properties:
                meal_id: { type: integer }
      responses:
        '200':
          description: Silindi
          content:
            application/json:
              schema:
                type: object
                properties:
                  status: { type: string, example: "deleted" }

  # ───────────────────────── SLEEP ─────────────────────────

  /sleep/addSleep:
    post:
      tags: [Sleep]
      summary: Uyku kaydı ekle
      description: "Sadece Student rolü."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [bed_time, wake_time]
              properties:
                bed_time: { type: string, example: "2026-07-22 23:30:00", description: "format: 2006-01-02 15:04:05" }
                wake_time: { type: string, example: "2026-07-23 07:15:00" }
      responses:
        '200':
          description: Uyku kaydı eklendi
          content:
            application/json:
              schema:
                type: object
                properties:
                  sleep: { $ref: '#/components/schemas/Sleep' }

  /sleep/getSleep:
    post:
      tags: [Sleep]
      summary: Öğrencinin uyku kayıtlarını getir
      description: "Hem Coach hem Student erişebilir. Coach ise `student_id` zorunludur."
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                student_id: { type: integer, description: "sadece Coach rolünde zorunlu, tam sayı olarak gönderilmeli" }
      responses:
        '200':
          description: Uyku kayıtları
          content:
            application/json:
              schema:
                type: object
                properties:
                  sleep: { $ref: '#/components/schemas/Sleep' }

  # ───────────────────────── RATINGS ─────────────────────────

  /rate/addRating:
    post:
      tags: [Ratings]
      summary: Ayrılınan bir koça puan/yorum bırak
      description: "Sadece Student rolü. Koçla ilişki 'breakup' durumunda olmalı."
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [coach_id, rate, description]
              properties:
                coach_id: { type: integer }
                rate: { type: number, description: "int'e çevrilir" }
                description: { type: string }
      responses:
        '200':
          description: Puan kaydedildi
          content:
            application/json:
              schema:
                type: object
                properties:
                  rating: { $ref: '#/components/schemas/Rating' }
        '400':
          description: "İlişki hâlâ aktif / daha önce puan verilmiş"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SimpleError' }

  /rate/getAvarage:
    post:
      tags: [Ratings]
      summary: Bir koçun ortalama puanını getir
      description: "Body gerekmez. NOT: route Student rolüne kayıtlı ama fonksiyon giriş yapan kullanıcının ID'sini coach_id gibi kullanıyor — muhtemelen bir tutarsızlık, kontrol edilmesi önerilir."
      responses:
        '200':
          description: Ortalama puan
          content:
            application/json:
              schema:
                type: object
                properties:
                  avarage: { type: number }

  # ───────────────────────── DOCUMENTS ─────────────────────────

  /document/addDocuments:
    post:
      tags: [Documents]
      summary: Belge yükle (tahlil, sertifika vb.)
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                files:
                  type: array
                  items: { type: string, format: binary }
                  description: "PDF, JPEG, PNG — sunucu tarafında AES-256 ile şifrelenip saklanır"
      responses:
        '200':
          description: Belgeler kaydedildi
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

  /document/getDocumentList:
    post:
      tags: [Documents]
      summary: Belge listesini getir (meta veri, dosya içeriği DEĞİL)
      description: "Hem Coach hem Student erişebilir. Coach ise `student_id` zorunludur ve aktif ilişki gerekir."
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                student_id: { type: integer, description: "sadece Coach rolünde zorunlu" }
      responses:
        '200':
          description: Belge listesi
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ResponseWrapper'
                  - type: object
                    properties:
                      data:
                        type: array
                        items: { $ref: '#/components/schemas/DocumentListItem' }

  /document/getDocument:
    post:
      tags: [Documents]
      summary: Tek bir belgenin (şifresi çözülmüş) içeriğini getir
      description: |
        Hem Coach hem Student erişebilir — Coach yalnızca kendi öğrencisinin,
        Student yalnızca kendi belgesini görebilir. Koç, koçun belgesini görebilir
        ama öğrenci koçun belgesini göremez.
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [file_id]
              properties:
                file_id: { type: integer }
      responses:
        '200':
          description: Belge içeriği (decrypt edilmiş ham byte'lar, data alanında)
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }
        '400':
          description: "Yetkisiz erişim / belge bulunamadı"
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ResponseWrapper' }

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:

    ResponseWrapper:
      type: object
      description: "utils.Response ile dönen standart zarf"
      properties:
        status: { type: boolean }
        banner: { type: string, nullable: true }
        data: { nullable: true }

    SimpleError:
      type: object
      description: "Bazı (özellikle eski/auth) endpoint'lerin döndürdüğü basit hata formatı"
      properties:
        error: { type: string }

    Coach:
      type: object
      properties:
        UserID: { type: integer }
        Speciality: { type: string }
        MaxStudents: { type: integer }
        Status: { type: string, description: "free | full" }

    Student:
      type: object
      properties:
        UserID: { type: integer }
        Age: { type: integer }
        BodyWeight: { type: number }
        FatPercentage: { type: number }
        BodyHeight: { type: number }

    Relation:
      type: object
      properties:
        ID: { type: integer }
        StudentID: { type: integer }
        CoachID: { type: integer }
        Status: { type: string, description: "waiting | active | rejected | expired | breakup" }
        RequestedTime: { type: string, format: date-time }
        DeletedTime: { type: string, format: date-time, nullable: true, description: "isteğin son cevaplanma tarihi" }
        StartedTime: { type: string, format: date-time, nullable: true }
        EndedTime: { type: string, format: date-time, nullable: true }

    AddWorkoutInput:
      type: object
      properties:
        workout_id: { type: integer }
        student_id: { type: integer }
        date: { type: string, format: date-time }
        note: { type: string }
        generator: { type: boolean, description: "false: koç girdi, true: öğrenci girdi" }
        source_plan_id: { type: integer, nullable: true }
        sets:
          type: array
          items: { $ref: '#/components/schemas/Set' }
        status: { type: string, description: "waiting | rejected | done" }

    Set:
      type: object
      description: "entities.Set — JSON tag'i yok, alan adları PascalCase gönderilir"
      properties:
        ID: { type: integer }
        WorkoutID: { type: integer }
        MovementName: { type: string }
        SetNumber: { type: integer }
        Reps: { type: integer }
        Weight: { type: number }
        Date: { type: string, format: date-time }

    Workout:
      type: object
      properties:
        ID: { type: integer }
        CoachID: { type: integer }
        StudentID: { type: integer }
        Date: { type: string, format: date-time }
        Notes: { type: string }
        Generator: { type: boolean }
        SourcePlanID: { type: integer, nullable: true }
        Status: { type: string, description: "waiting | rejected | done" }

    WorkoutM:
      type: object
      description: "Frontend'e dönen, Set'leriyle birlikte antrenman modeli"
      properties:
        id: { type: integer }
        coach_id: { type: integer }
        student_id: { type: integer }
        date: { type: string, format: date-time }
        notes: { type: string }
        status: { type: string }
        generator: { type: boolean }
        source_plan_id: { type: integer, nullable: true }
        sets:
          type: array
          items: { $ref: '#/components/schemas/Set' }

    Meal:
      type: object
      properties:
        ID: { type: integer }
        StudentID: { type: integer }
        MealName: { type: string }
        Description: { type: string }
        Kcal: { type: number }
        Protein: { type: number }
        Oil: { type: number }
        Date: { type: string, format: date-time }

    MealSummary:
      type: object
      description: "GetMealSumDaily'nin döndürdüğü, güne göre toplanmış öğün verisi"
      properties:
        Date: { type: string, format: date-time }
        StudentID: { type: integer }
        Kcal: { type: number, description: "günün toplam kalorisi" }
        Protein: { type: number }
        Oil: { type: number }

    Sleep:
      type: object
      properties:
        ID: { type: integer }
        StudentID: { type: integer }
        BedTime: { type: string, format: date-time }
        WakeTime: { type: string, format: date-time }

    Rating:
      type: object
      properties:
        ID: { type: integer }
        StudentID: { type: integer }
        CoachID: { type: integer }
        Score: { type: integer }
        Description: { type: string }
        CreateTime: { type: string, format: date-time }

    DocumentListItem:
      type: object
      properties:
        ID: { type: integer }
        DocName: { type: string }
        DocType: { type: string, description: "MIME type, örn: application/pdf" }
        Date: { type: string, format: date-time }