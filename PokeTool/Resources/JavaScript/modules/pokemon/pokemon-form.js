"use strict";
const actions = require("./pokemon-actions");

async function fillProfile(browser, profile) {
  const values = profile || {};
  const fields = [
    ["#registration-form-fname", values.name],
    ["#registration-form-kana", values.kana],
    ["#registration-form-postcode", values.postcode],
    ["#registration-form-address-level2", values.city],
    ["#registration-form-address-line1", values.addressLine1 || values.address1],
    ["#registration-form-address-line2", values.addressLine2 || values.address2],
    ["[name='dwfrm_profile_customer_phone']", values.phone],
    ["[name='dwfrm_profile_login_password']", values.password],
    ["[name='dwfrm_profile_login_passwordconfirm']", values.password]
  ];
  for (const field of fields) {
    if (field[1] !== undefined) await actions.setAndVerify(browser, field[0], field[1], false);
  }
  if (values.pref !== undefined && await browser.exists("#registration-form-address-level1")) {
    await browser.selectValue("#registration-form-address-level1", String(values.pref));
  }
  if (values.birthdate) {
    const parts = String(values.birthdate).split("-");
    if (parts.length === 3) {
      await browser.selectValue("#registration-form-birthdayyear", parts[0]);
      await browser.selectValue("#registration-form-birthdaymonth", String(Number(parts[1])));
      await browser.selectValue("#registration-form-birthdayday", String(Number(parts[2])));
    }
  }
  for (const selector of [
    "input[name='dwfrm_profile_customer_addtoemaillist'][value='false']",
    "[name='dwfrm_profile_customer_agreetotheterms']",
    "[name='dwfrm_profile_customer_agreetotheprivacypolicy']"
  ]) if (await browser.exists(selector)) await browser.setChecked(selector, true);
}
async function fillOrderAddress(browser, profile) {
  const fields = [
    ["#name", profile.name], ["#kana", profile.kana],
    ["#postal-code", profile.postcode], ["#address-level2", profile.city],
    ["#address-line1", profile.address1], ["#address-line2", profile.address2],
    ["#phone", profile.phone]
  ];
  for (const field of fields) if (field[1] !== undefined) {
    await actions.setAndVerify(browser, field[0], field[1], false);
  }
  if (profile.pref !== undefined && await browser.exists("#address-level1")) {
    await browser.selectValue("#address-level1", String(profile.pref));
  }
}
module.exports = {fillProfile,fillOrderAddress};
