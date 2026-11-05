import Foundation

/// App 内的隐私政策、用户协议。由 tools/render.py 根据 tools/templates/*.md 生成，要改内容请改模板。
enum LegalText {
    static var privacy: String { L10n.lang == "en" ? privacyEN : L10n.lang == "zh-Hant" ? privacyHant : privacyZH }
    static var terms: String { L10n.lang == "en" ? termsEN : L10n.lang == "zh-Hant" ? termsHant : termsZH }

    static let privacyZH = """
**准点时钟 隐私政策**

更新日期：2026 年 11 月 5 日
生效日期：2026 年 11 月 5 日

准点时钟（以下简称"本 App"）由个人开发者 lang qin 开发和运营。我们非常重视你的隐私，本政策说明本 App 会处理哪些信息、为什么处理以及你的权利。

**一、我们不收集你的个人数据**

本 App 不需要注册或登录，也没有自己的服务器。你在本 App 中添加的抢购日程、头像、昵称和各项设置，全部只保存在你的手机上，我们看不到、也拿不到这些内容。

**二、需要用到的手机权限**

以下权限都只在你使用相关功能时才会请求，你可以拒绝，也可以随时在系统"设置"里关闭，关闭后不影响其他功能：

• 日历：你点「从日历添加」时使用，读取未来半年的日程供你选择，选中的时间填到抢购活动里。只在手机上读取，不会上传。
• 相机：你扫描二维码添加抢购活动时使用，也可以在设置头像时拍照。画面只在手机上识别，不会上传。
• 相册：你从相册选二维码图片或头像时使用，选中的图片只在本机处理和保存。
• 通知：用于开抢前的提醒和你选的通知闹钟，提醒在本机安排，不经过网络。
• 实时活动：用于在灵动岛和锁屏上显示开抢倒计时，内容只在本机。
• 剪贴板：打开添加页时只询问系统「剪贴板里像不像网址」，不读取内容；你点「使用」或粘贴时才读取，只用来填写这一场。

**三、用户 ID**

本 App 会在本机随机生成一个 8 位数字的用户 ID，保存在系统钥匙串里（如果你开启了 iCloud 钥匙串，会随你的 Apple ID 同步）。它不包含任何个人身份信息，只用于你在"意见反馈"时方便我们定位问题。

**四、意见反馈**

"意见反馈"页面由腾讯问卷（wj.qq.com）提供。为了方便排查问题，打开问卷时会自动填写你的用户 ID、会员类型和 App 版本号；你在问卷里填写的内容（包括你自愿留下的联系方式和截图）由问卷服务按照其隐私政策处理，只有开发者能看到。不打开反馈页面时，不会传递任何信息。

**五、联网的功能**

• 对时：向授时服务和你选择的平台公开的时间接口查询当前时间，只读取时间，不发送你的个人信息。
• 读取链接：你粘贴或扫码添加抢购链接时，你的手机会在后台打开这个页面（包括短链接跳转到的页面），页面自己的脚本会向平台请求数据，本 App 从页面内容和这些数据里取出活动标题和开抢时间，先给你确认，再填到编辑页。不登录、不带你的账号信息，也不保留 Cookie，结果只保存在本机。平台会像收到普通网页访问一样收到这次请求（比如 IP 地址）。
• 会员购买：购买和恢复购买由 Apple 处理，本 App 只向 Apple 查询商品价格和你的购买状态，拿不到你的支付信息。
• 检查更新：会向 Apple 的 App Store 查询最新版本号，不发送你的个人信息。
• 打开抢购页等外部网页或 App 时，由对应的平台按其规则处理。

**六、第三方 SDK**

本 App 没有接入任何第三方 SDK（包括广告、统计和推送 SDK）。

**七、数据的保存和删除**

你可以在"设置"里清空抢购。删除本 App 会同时删除本机上的抢购日程、头像和设置，用户 ID 保存在系统钥匙串里，可能不会一起删除。因为我们没有你的数据，所以无法替你找回或删除，删除完全由你在手机上完成。

**八、未成年人保护**

如果你是未满 14 周岁的未成年人，请在监护人同意和指导下阅读本政策并使用本 App。

**九、政策更新与联系我们**

本政策有重要更新时，会在 App 内再次请你阅读并同意。如有任何疑问、意见或投诉，可以通过 App 里的"意见反馈"联系我们，我们会在 15 个工作日内回复。
"""

    static let termsZH = """
**准点时钟 用户协议**

更新日期：2026 年 11 月 5 日

欢迎使用准点时钟（以下简称"本 App"）。本 App 由个人开发者 lang qin 开发和运营。使用本 App 前请仔细阅读本协议，点"同意并继续"或继续使用即表示你同意本协议。

**一、服务内容**

本 App 提供平台对时、毫秒开抢倒计时、悬浮窗、灵动岛、开抢提醒和通知闹钟等功能，帮助你看准开抢时间。本 App 不会替你下单或抢购，也不保证你一定能抢到。

**二、费用**

基础功能免费，最多同时 3 场。会员权益（全程无广告、不限场次）需要付费开通：永久会员一次购买；季度会员每 3 个月自动续订，到期前 24 小时内扣费，可随时在系统「设置 → Apple 账户 → 订阅」里取消。费用由 Apple 收取，具体价格以购买页显示为准。会员跟你的 Apple 账号走，换手机后可以在会员页点「恢复购买」。

**三、你的数据**

你在本 App 中添加的内容归你所有。数据只保存在本机，本 App 不提供备份。因手机丢失、损坏、删除 App 等原因造成的数据丢失，我们无法帮你找回。

**四、使用规范**

请遵守法律法规和各平台的规则，不要利用本 App 从事违法活动，也不要通过意见反馈发布违法、侵权、骚扰内容。

**五、免责说明**

1. 对时结果受网络和平台接口影响，可能有误差，实际开抢以平台为准。
2. 从链接或分享文字读到的标题和开抢时间可能不准，请和平台核对。
3. 提醒、悬浮窗和灵动岛受系统设置和手机状态影响，可能不出现或不及时。
4. 本 App 和文中提到的任何平台都没有关联，开抢时间、库存、订单都由平台决定。因以上原因没有抢到的，我们不承担责任。

**六、协议变更**

协议有重要更新时会在 App 内再次请你阅读并同意。如有疑问，可以通过"意见反馈"联系我们。
"""

    static let privacyEN = """
**OnTime Clock Privacy Policy**

Last updated: November 5, 2026
Effective: November 5, 2026

OnTime Clock ("the App") is developed and operated by independent developer lang qin. We take your privacy seriously. This policy explains what information the App handles, why, and your rights.

**1. We don’t collect your personal data**

The App requires no sign-up or login and has no servers of its own. The sale events, avatar, nickname and settings you add are stored only on your phone. We can’t see or access any of them.

**2. Phone permissions**

The following permissions are requested only when you use the related feature. You can decline them or turn them off anytime in the system Settings; other features keep working:

• Calendar: used when you tap “From calendar”. It reads your events for the next six months so you can choose one, and fills its time into the sale. It stays on your phone and is never uploaded.
• Camera: used when you scan a QR code to add a sale event, or take a photo for your avatar. The image is read on your phone and never uploaded.
• Photos: used when you choose a QR code image or an avatar. The selected image is processed and stored only on your device.
• Notifications: used for reminders before a sale starts and the alarm sound you choose. Reminders are scheduled on your device without going through the network.
• Live Activities: used to show the sale countdown on the Dynamic Island and Lock Screen. The content stays on your device.
• Clipboard: when you open the add screen, the App only asks the system whether the clipboard looks like a web address, without reading it. The content is read only when you tap “Use” or paste, and only to fill in this sale.

**3. User ID**

The App generates a random 8-digit user ID on your device and stores it in the system Keychain (if iCloud Keychain is on, it syncs with your Apple ID). It contains no personal identity information and is only used to help us locate issues when you send feedback.

**4. Feedback**

The Feedback page is provided by Tencent Survey (wj.qq.com). To help troubleshoot, your user ID, plan type and app version are filled in automatically when the survey opens. What you enter (including any contact details and screenshots you choose to leave) is handled by the survey service under its privacy policy and is visible only to the developer. Nothing is sent unless you open the Feedback page.

**5. Features that use the network**

• Time sync: asks time services and the public time endpoints of the platforms you choose for the current time. Only the time is read; no personal information is sent.
• Reading links: when you paste or scan a sale link, your phone opens that page in the background (including the page a short link redirects to). The page’s own scripts request data from the platform, and the App picks the event title and sale time out of the page and that data, asks you to confirm, then fills them into the editor. It doesn’t log in, send your account information or keep cookies, and the result stays only on your device. The platform receives this like any ordinary web visit (for example, your IP address).
• Membership: purchases and restores are handled by Apple. The App only asks Apple for product prices and your purchase status, and never receives your payment information.
• Check for updates: asks Apple’s App Store for the latest version number; no personal information is sent.
• Sale pages and other external websites or apps you open are handled by those platforms under their own rules.

**6. Third-party SDKs**

The App does not include any third-party SDKs (including advertising, analytics or push SDKs).

**7. Storing and deleting data**

You can clear your sales in Settings. Deleting the App deletes your sales, avatar and settings from your device; the user ID is kept in the system Keychain and may not be deleted with it. Because we don’t have your data, we can’t recover or delete it for you; deletion is done entirely by you on your phone.

**8. Children**

If you are under 14, please read this policy and use the App with the consent and guidance of a parent or guardian.

**9. Updates and contact**

If this policy changes significantly, the App will ask you to read and agree to it again. For any questions, comments or complaints, contact us via Feedback in the App. We will reply within 15 business days.
"""

    static let termsEN = """
**OnTime Clock Terms of Use**

Last updated: November 5, 2026

Welcome to OnTime Clock ("the App"). The App is developed and operated by independent developer lang qin. Please read these terms carefully before using the App. By tapping “Agree and continue” or continuing to use the App, you agree to these terms.

**1. Service**

The App offers platform time sync, millisecond sale countdowns, a floating window, Dynamic Island, sale reminders and alarm sounds to help you catch the moment a sale opens. The App does not place orders for you and does not guarantee that you will get what you want.

**2. Price**

Basic features are free, with up to 3 sales at a time. Member benefits (no ads and unlimited sales) are paid: Lifetime is a one-time purchase; Quarterly renews automatically every 3 months, is charged within 24 hours before the period ends, and can be cancelled anytime in Settings > Apple Account > Subscriptions. Apple charges the fee, and the price is shown on the purchase page. Membership follows your Apple Account; on a new phone, tap Restore Purchases on the membership page.

**3. Your data**

The content you add in the App belongs to you. Data is stored only on your device, and the App doesn’t offer backups. We can’t recover data lost because your phone is lost or damaged, the App is deleted, or for similar reasons.

**4. Acceptable use**

Please follow applicable laws and each platform’s rules. Don’t use the App for illegal activities, and don’t post illegal, infringing or harassing content through Feedback.

**5. Disclaimer**

1. Time sync depends on the network and platform endpoints and may be off; the platform decides when a sale actually opens.
2. Titles and sale times read from links or shared text may be wrong; please check them against the platform.
3. Reminders, the floating window and Dynamic Island depend on system settings and your phone’s state, and may not appear or may be late.
4. The App is not affiliated with any platform it mentions. Sale times, stock and orders are decided by the platforms. We are not responsible for missed purchases for these reasons.

**6. Changes**

If these terms change significantly, the App will ask you to read and agree to them again. For questions, contact us via Feedback.
"""

    static let privacyHant = """
**準點時鐘 隱私政策**

更新日期：2026 年 11 月 5 日
生效日期：2026 年 11 月 5 日

準點時鐘（以下簡稱"本 App"）由個人開發者 lang qin 開發和運營。我們非常重視你的隱私，本政策說明本 App 會處理哪些資訊、為什麼處理以及你的權利。

**一、我們不收集你的個人資料**

本 App 不需要註冊或登入，也沒有自己的伺服器。你在本 App 中新增的搶購日程、頭像、暱稱和各項設定，全部只儲存在你的手機上，我們看不到、也拿不到這些內容。

**二、需要用到的手機許可權**

以下許可權都只在你使用相關功能時才會請求，你可以拒絕，也可以隨時在系統"設定"裡關閉，關閉後不影響其他功能：

• 日曆：你點「從日曆新增」時使用，讀取未來半年的日程供你選擇，選中的時間填到搶購活動裡。只在手機上讀取，不會上傳。
• 相機：你掃描二維碼新增搶購活動時使用，也可以在設定頭像時拍照。畫面只在手機上識別，不會上傳。
• 相簿：你從相簿選二維碼圖片或頭像時使用，選中的圖片只在本機處理和儲存。
• 通知：用於開搶前的提醒和你選的通知鬧鐘，提醒在本機安排，不經過網路。
• 即時活動：用於在靈動島和鎖屏上顯示開搶倒計時，內容只在本機。
• 剪貼簿：開啟新增頁時只詢問系統「剪貼簿裡像不像網址」，不讀取內容；你點「使用」或貼上時才讀取，只用來填寫這一場。

**三、使用者 ID**

本 App 會在本機隨機生成一個 8 位數字的使用者 ID，儲存在系統鑰匙串裡（如果你開啟了 iCloud 鑰匙串，會隨你的 Apple ID 同步）。它不包含任何個人身份資訊，只用於你在"意見反饋"時方便我們定位問題。

**四、意見反饋**

"意見反饋"頁面由騰訊問卷（wj.qq.com）提供。為了方便排查問題，開啟問卷時會自動填寫你的使用者 ID、會員型別和 App 版本號；你在問卷裡填寫的內容（包括你自願留下的聯絡方式和截圖）由問卷服務按照其隱私政策處理，只有開發者能看到。不開啟反饋頁面時，不會傳遞任何資訊。

**五、聯網的功能**

• 對時：向授時服務和你選擇的平臺公開的時間介面查詢當前時間，只讀取時間，不傳送你的個人資訊。
• 讀取連結：你貼上或掃碼新增搶購連結時，你的手機會在後臺開啟這個頁面（包括短連結跳轉到的頁面），頁面自己的指令碼會向平臺請求資料，本 App 從頁面內容和這些資料裡取出活動標題和開搶時間，先給你確認，再填到編輯頁。不登入、不帶你的帳號資訊，也不保留 Cookie，結果只儲存在本機。平臺會像收到普通網頁訪問一樣收到這次請求（比如 IP 地址）。
• 會員購買：購買和恢復購買由 Apple 處理，本 App 只向 Apple 查詢商品價格和你的購買狀態，拿不到你的支付資訊。
• 檢查更新：會向 Apple 的 App Store 查詢最新版本號，不傳送你的個人資訊。
• 開啟搶購頁等外部網頁或 App 時，由對應的平臺按其規則處理。

**六、第三方 SDK**

本 App 沒有接入任何第三方 SDK（包括廣告、統計和推送 SDK）。

**七、資料的儲存和刪除**

你可以在"設定"裡清空搶購。刪除本 App 會同時刪除本機上的搶購日程、頭像和設定，使用者 ID 儲存在系統鑰匙串裡，可能不會一起刪除。因為我們沒有你的資料，所以無法替你找回或刪除，刪除完全由你在手機上完成。

**八、未成年人保護**

如果你是未滿 14 週歲的未成年人，請在監護人同意和指導下閱讀本政策並使用本 App。

**九、政策更新與聯絡我們**

本政策有重要更新時，會在 App 內再次請你閱讀並同意。如有任何疑問、意見或投訴，可以通過 App 裡的"意見反饋"聯絡我們，我們會在 15 個工作日內回覆。
"""

    static let termsHant = """
**準點時鐘 使用者協議**

更新日期：2026 年 11 月 5 日

歡迎使用準點時鐘（以下簡稱"本 App"）。本 App 由個人開發者 lang qin 開發和運營。使用本 App 前請仔細閱讀本協議，點"同意並繼續"或繼續使用即表示你同意本協議。

**一、服務內容**

本 App 提供平臺對時、毫秒開搶倒計時、懸浮窗、靈動島、開搶提醒和通知鬧鐘等功能，幫助你看準開搶時間。本 App 不會替你下單或搶購，也不保證你一定能搶到。

**二、費用**

基礎功能免費，最多同時 3 場。會員權益（全程無廣告、不限場次）需要付費開通：永久會員一次購買；季度會員每 3 個月自動續訂，到期前 24 小時內扣費，可隨時在系統「設定 → Apple 帳號 → 訂閱」裡取消。費用由 Apple 收取，具體價格以購買頁顯示為準。會員跟你的 Apple 帳號走，換手機後可以在會員頁點「恢復購買」。

**三、你的資料**

你在本 App 中新增的內容歸你所有。資料只儲存在本機，本 App 不提供備份。因手機丟失、損壞、刪除 App 等原因造成的資料丟失，我們無法幫你找回。

**四、使用規範**

請遵守法律法規和各平臺的規則，不要利用本 App 從事違法活動，也不要通過意見反饋釋出違法、侵權、騷擾內容。

**五、免責說明**

1. 對時結果受網路和平臺介面影響，可能有誤差，實際開搶以平臺為準。
2. 從連結或分享文字讀到的標題和開搶時間可能不準，請和平臺核對。
3. 提醒、懸浮窗和靈動島受系統設定和手機狀態影響，可能不出現或不及時。
4. 本 App 和文中提到的任何平臺都沒有關聯，開搶時間、庫存、訂單都由平臺決定。因以上原因沒有搶到的，我們不承擔責任。

**六、協議變更**

協議有重要更新時會在 App 內再次請你閱讀並同意。如有疑問，可以通過"意見反饋"聯絡我們。
"""
}
