"use strict";
const Pages=require("./jumpcs-pages");const Actions=require("./jumpcs-actions");const errors=require("./jumpcs-errors");
function productURL(task){const p=task.product||{};if(p.url){const u=String(p.url);if(!/^https:\/\/jumpcs\.shueisha\.co\.jp\/shop\/g\/g[A-Za-z0-9_-]+\/?$/.test(u))throw errors.create("JUMPCS_PRODUCT_URL_INVALID","Product URL is outside the JumpCS product root.",{step:"PRODUCT"});return u;}if(!p.productCode)throw errors.create("JUMPCS_PRODUCT_URL_INVALID","Product code is missing.",{step:"PRODUCT"});return "https://jumpcs.shueisha.co.jp/shop/g/g"+encodeURIComponent(p.productCode)+"/";}
async function open(session,task,c){return Actions.open(session,"PRODUCT",productURL(task),c);}
async function summary(browser){return browser.evaluate(`(function(){const q=s=>document.querySelector(s);const code=(q('[data-product-code]')||q('input[name="productCode"]'));const price=q('.price,[data-price]');return {productCode:code&&String(code.value||code.getAttribute('data-product-code')||''),price:price&&String(price.textContent||'').trim(),available:Boolean(q('#cart_button')&&!q('#cart_button').disabled)};})()`);}
module.exports={productURL,open,summary};
