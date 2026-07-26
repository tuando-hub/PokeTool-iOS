"use strict";
// Sanitized state fixtures model real selectors without real accounts, tokens, or payment data.
const base=(title,body)=>`<!doctype html><html><head><title>${title}</title></head><body>${body}</body></html>`;
module.exports=Object.freeze({
  home:base("少年ジャンプ＋","<header><a class='js-login-button'>ログイン／新規登録</a></header>"),
  login:base("少年ジャンプ＋","<form action='/user_account/login'><input name='email_address'><input name='password' type='password'><button class='js-signup-button'>新規登録</button></form>"),
  signup:base("少年ジャンプ＋","<form class='js-signup-form'><input name='email_address'><input name='password' type='password'><input id='input-agreement' type='checkbox'><button>新規会員登録</button></form>"),
  signupValidation:base("少年ジャンプ＋","<form class='js-signup-form'><p class='error'>入力内容を確認してください</p></form>"),
  mailSent:base("少年ジャンプ＋","<main><p>登録メールを送信しました</p></main>"),
  duplicate:base("少年ジャンプ＋","<main><p class='error'>既に登録されています</p></main>"),
  confirmed:base("登録完了 | 少年ジャンプ＋","<main data-account-confirmed='true'><h1>登録完了</h1></main>"),
  confirmationExpired:base("リンクエラー | 少年ジャンプ＋","<main class='error'><h1>有効期限切れ</h1></main>"),
  loggedIn:base("少年ジャンプ＋","<header><nav class='plus-header-nav-account'>アカウント</nav></header>"),
  premium:base("定期購読 | 少年ジャンプ＋","<main data-product-id='10834108156675977993'><button>決済方法を選択する</button></main>"),
  alreadySubscribed:base("定期購読 | 少年ジャンプ＋","<li class='plus-header-nav-premium js-show-for-premium'>定期購読中</li>"),
  unavailable:base("定期購読 | 少年ジャンプ＋","<main class='product-unavailable'>商品を購入できません</main>"),
  methods:base("決済方法 | 少年ジャンプ＋","<main><a class='payment_choose_credit_3d'>クレジット(3Dセキュア)</a></main>"),
  credit:base("カード情報 | 少年ジャンプ＋","<form name='creditFepChargePaymentInfoEntryActionForm'><input name='ccNumber'><select name='ccExpirationMonth'></select><select name='ccExpirationYear'></select><input name='securityCode'><a>次へ</a></form>"),
  creditValidation:base("カード情報 | 少年ジャンプ＋","<form name='creditFepChargePaymentInfoEntryActionForm'><p class='error'>カード情報を確認してください</p></form>"),
  review:base("購入確認 | 少年ジャンプ＋","<form name='fepChargeIntensionConfirmActionForm'><button>購入</button></form>"),
  threeDS:base("本人認証","<form id='challengeForm'><iframe name='challengeFrame'></iframe></form>"),
  complete:base("購読完了 | 少年ジャンプ＋","<main class='subscription-complete'><h1>購入完了</h1></main>"),
  rejected:base("決済エラー | 少年ジャンプ＋","<main class='payment-error'>決済できませんでした</main>"),
  maintenance:base("メンテナンス | 少年ジャンプ＋","<main class='maintenance'>メンテナンス中</main>"),
  captcha:base("セキュリティ確認 | 少年ジャンプ＋","<main class='captcha'><div class='g-recaptcha'></div></main>"),
  rateLimited:base("アクセス制限 | 少年ジャンプ＋","<main class='rate-limit'>しばらくしてからお試しください</main>"),
  sessionExpired:base("ログイン | 少年ジャンプ＋","<main class='session-expired'>再度ログインしてください</main>"),
  genericError:base("エラー | 少年ジャンプ＋","<main class='error'>エラーが発生しました</main>")
});
