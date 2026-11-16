# Badminton Squad

Badminton Squad là ứng dụng Flutter hỗ trợ câu lạc bộ cầu lông xếp lịch đánh đôi, chấm điểm và chia chi phí buổi đánh. Trang chủ Quick Match dùng danh sách người chơi do Admin nhập, không tự nạp roster mẫu.

## 1. Tính năng

- **Quick Match:** Admin nhập nhanh/dán danh sách người chơi, chọn trình độ, đánh dấu người đến trễ/về sớm và chọn 1–2 sân.
- **Chia cặp đôi:** engine cân bằng Elo, ưu tiên người có ít trận hơn, tránh lặp cặp và nhận diện đôi có tỷ lệ thắng trên 75% sau tối thiểu 4 kết quả.
- **Điều chỉnh đội hình:** Admin nhấn giữ và kéo người chơi sang vị trí khác để hoán đổi; chênh lệch trình độ và tên trên bảng điểm được tính lại.
- **Tính tiền buổi đánh:** chia tiền sân theo hệ số tham gia (0,5 hoặc 1), tính tiền cầu theo số quả đã đánh và chia đều giữa thành viên.
- **VietQR trên Quick Match:** tạo payload EMVCo cùng CRC-16/CCITT-FALSE ngay trên thiết bị rồi render QR cục bộ bằng `qr_flutter`; không gọi dịch vụ tạo ảnh bên ngoài.
- **Camera bảng điểm:** mở camera toàn màn hình, chạm để cộng điểm, vuốt xuống để hoàn tác, bật/tắt ghi hình và nhận phản hồi rung.
- **Ước lượng smash:** `BadmintonPhysicsEngine` suy ngược vận tốc rời vợt từ vận tốc trung bình và thời gian bay theo mô hình suy giảm mũ `k = 0.0021 s⁻¹`; đây là ước lượng, không thay thế cảm biến đo.
- **Cyber-sports UI:** thẻ kính mờ, nút nảy, danh sách/trận đấu chuyển động, điểm số lăn và hiệu ứng shockwave cho kỷ lục tốc độ.
- **Tự lưu cục bộ:** roster, lượt đấu, tỉ số, lịch sử ghép cặp và cấu hình chi phí được lưu bằng `shared_preferences`, tự khôi phục khi mở lại app.
- **Elo đôi:** tính Elo sau khi Admin nhập kết quả; hiệu chỉnh theo cách biệt điểm.
- **Giao diện:** dark theme phong cách thể thao, màu xanh neon và vàng chanh.
- **Supabase:** có schema SQL cho profiles, sessions, attendance, matches, bills, payments và payment settings.

> **Trạng thái hiện tại:** Quick Match được lưu cục bộ trên thiết bị; dữ liệu chưa được đồng bộ giữa nhiều thiết bị. Autosave giúp khôi phục sau khi mở lại app, nhưng bộ nhớ ứng dụng bị xóa hoặc lỗi thiết bị vẫn có thể làm mất dữ liệu. Supabase có thể được khởi tạo bằng cấu hình, nhưng đăng nhập và đọc/ghi dữ liệu thật chưa được nối vào các màn hình. Elo và thanh toán hiện chưa đồng bộ với database.

## 2. Cấu hình tài khoản nhận VietQR

Thông tin người nhận hiện được truyền vào lúc chạy ứng dụng, không cần sửa mã nguồn hay đưa thông tin tài khoản vào Git. Các giá trị được đọc tại [mobile/lib/main.dart](mobile/lib/main.dart):

| Tham số | Giá trị cần nhập |
| --- | --- |
| `VIETQR_BANK_BIN` | Mã BIN VietQR/NAPAS gồm **6 chữ số** của ngân hàng. Mã này thay cho tên ngân hàng dạng chữ. Hãy xác nhận mã chính xác với ngân hàng hoặc danh sách BIN đáng tin cậy. |
| `VIETQR_ACCOUNT_NUMBER` | Số tài khoản nhận tiền, từ 6 đến 32 ký tự chữ hoặc số. |
| `VIETQR_ACCOUNT_NAME` | Tên chủ tài khoản đúng như ngân hàng đăng ký. |

Ví dụ chạy trên Chrome bằng PowerShell (thay toàn bộ giá trị mẫu bằng thông tin của bạn):

```powershell
cd .\mobile
flutter run -d chrome `
  --dart-define=VIETQR_BANK_BIN=YOUR_6_DIGIT_BANK_BIN `
  --dart-define=VIETQR_ACCOUNT_NUMBER=YOUR_ACCOUNT_NUMBER `
  --dart-define="VIETQR_ACCOUNT_NAME=YOUR ACCOUNT HOLDER NAME"
```

Thêm cùng ba tham số `--dart-define` vào lệnh chạy Android ở phần dưới nếu muốn tạo VietQR trên thiết bị đó. Sau khi đổi thông tin, hãy chạy lại ứng dụng với các giá trị mới. Nếu thiếu bất kỳ giá trị nào, VietQR sẽ không được bật. Nội dung QR được tạo và vẽ ngay trên thiết bị, không cần kết nối API tạo ảnh; hãy xác minh ngân hàng, số tài khoản và tên người nhận trước khi chia sẻ.

## 3. Cài Flutter và chạy ứng dụng

### Cài công cụ

1. Cài **Git for Windows** và **Flutter SDK stable** theo [hướng dẫn cài Flutter chính thức](https://docs.flutter.dev/install/manual). Dùng Flutter có Dart đáp ứng ràng buộc `>=3.5.0` trong [mobile/pubspec.yaml](mobile/pubspec.yaml).
2. Thêm thư mục `flutter\bin` vào Windows `PATH`, mở lại PowerShell/VS Code và kiểm tra:

   ```powershell
   flutter --version
   flutter doctor
   ```

3. Nếu muốn chạy Android, cài **Android Studio**, Android SDK và Android Emulator. Chấp nhận các giấy phép Android nếu `flutter doctor` yêu cầu:

   ```powershell
   flutter doctor --android-licenses
   ```

4. Cài Google Chrome để chạy bản web. Có thể cài extension Flutter và Dart trong VS Code để hỗ trợ phát triển.

### Chuẩn bị project lần đầu

Thư mục `mobile` hiện có mã nguồn Dart và `pubspec.yaml`, nhưng chưa có thư mục nền tảng Android/Web. Từ PowerShell tại thư mục gốc dự án, tạo các thư mục này **một lần**:

```powershell
cd .\mobile
flutter create --platforms=web,android .
flutter pub get
flutter devices
```

Nếu bản sao dự án của bạn đã có thư mục `web` và `android`, bỏ qua lệnh `flutter create`. Lệnh `flutter pub get` tải các package khai báo trong `pubspec.yaml`.

### Chạy trên Chrome

```powershell
cd .\mobile
flutter run -d chrome
```

Cho phép trình duyệt truy cập camera khi được hỏi. Khả năng ghi hình phụ thuộc vào trình duyệt và quyền camera; nếu cần kiểm tra đầy đủ camera/ghi hình, nên thử trên điện thoại Android thật.

### Chạy trên Android Emulator

1. Mở Android Studio, tạo và khởi động một thiết bị ảo trong **Device Manager**.
2. Xem ID thiết bị:

   ```powershell
   flutter devices
   ```

3. Gán `$deviceId` bằng ID hiển thị (ví dụ `emulator-5554`), rồi chạy:

   ```powershell
   $deviceId = "emulator-5554"
   flutter run -d $deviceId
   ```

### Chạy trên điện thoại Android thật

1. Bật **Developer options** và **USB debugging** trên điện thoại.
2. Kết nối điện thoại bằng cáp USB, mở khóa và chấp nhận hộp thoại cho phép gỡ lỗi USB.
3. Chạy `flutter devices`, sau đó:

   ```powershell
   $deviceId = "ID_CUA_DIEN_THOAI"
   flutter run -d $deviceId
   ```

Để bật VietQR, thêm các tham số `--dart-define` ở mục 2 vào lệnh `flutter run`. Không đưa Supabase `service_role` key vào ứng dụng; chỉ dùng publishable/anon key dành cho client.

## 4. Tạo schema trên Supabase

1. Tạo một project tại [Supabase Dashboard](https://supabase.com/dashboard).
2. Trong project, mở **SQL Editor** → **New query**.
3. Mở [supabase/schema.sql](supabase/schema.sql), sao chép toàn bộ nội dung, dán vào SQL Editor và nhấn **Run**. Schema này dành cho project mới và chỉ nên áp dụng một lần; không chạy lại nguyên file trên database đã có các bảng/policy tương ứng.
4. Kiểm tra các bảng đã tạo trong **Table Editor**. File schema không chèn dữ liệu mẫu; dữ liệu mẫu của ứng dụng nằm riêng trong [mobile/lib/core/mock/mock_data.dart](mobile/lib/core/mock/mock_data.dart).
5. Tạo/đăng ký tài khoản Admin đầu tiên. Trigger tạo profile mới với `is_active = false`, vì vậy tài khoản chưa thể dùng các policy dành cho thành viên đang hoạt động. Trong **Authentication → Users**, sao chép UUID người dùng vừa tạo, rồi chạy trong SQL Editor:

   ```sql
   update public.profiles
   set role = 'admin',
       is_active = true
   where id = 'PASTE_AUTH_USER_UUID_HERE'::uuid;
   ```

6. Khi chạy ứng dụng, truyền **Project URL** và **publishable/anon key** bằng compile-time defines:

   ```powershell
   flutter run -d chrome `
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
   ```

Schema bật Row Level Security (RLS) và giới hạn thao tác theo thành viên/Admin. Không tắt RLS để “sửa cho chạy” và tuyệt đối không nhúng `service_role` key vào app. Bước cấu hình trên tạo database và khởi tạo Supabase client; **các màn hình hiện vẫn dùng mock data, chưa tự đồng bộ với các bảng online**. Cần bổ sung luồng đăng nhập và tầng đọc/ghi Supabase trước khi xem đây là dữ liệu sản xuất.
