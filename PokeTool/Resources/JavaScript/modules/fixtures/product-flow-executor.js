"use strict";
const product = require("/modules/product/product-entry");

const HOME = {
  name:"Fixture Home",
  url:{type:"exact",value:"about:blank"},
  title:{type:"exact",value:"Fixture Home"},
  selectors:[{name:"home-marker",selector:"#home",state:"visible"}],
  readyState:["interactive","complete"]
};
const LOGIN = {
  name:"Fixture Login",
  url:{type:"exact",value:"about:blank"},
  title:{type:"exact",value:"Fixture Login"},
  selectors:[
    {name:"login-marker",selector:"#login",state:"visible"},
    {name:"submit",selector:"#submit",state:"visible"}
  ]
};
const LOADING = {
  name:"Fixture Loading",
  title:{type:"exact",value:"Fixture Loading"},
  selectors:[{name:"loading",selector:"#loading",state:"visible"}]
};
const DASHBOARD = {
  name:"Fixture Dashboard",
  url:{type:"exact",value:"about:blank"},
  title:{type:"exact",value:"Fixture Dashboard"},
  selectors:[{name:"dashboard",selector:"#dashboard",state:"visible"}],
  text:{includes:"Ready"}
};

module.exports = async function executeFixture(task, runnerContext) {
  const browser = await PokeToolRuntime.browser.create();
  try {
    await browser.load("about:blank");
    await PokeToolRuntime.web.waitPageReady(browser, 3000);
    await browser.evaluate(`
      document.title = "Fixture Home";
      document.body.innerHTML =
        '<main id="home" style="display:block;width:200px;height:40px">Home</main>' +
        '<button id="login-button" style="width:100px;height:30px">Login</button>';
      document.querySelector("#login-button").addEventListener("click", function () {
        document.title = "Fixture Login";
        document.body.innerHTML =
          '<form id="login" style="display:block;width:200px;height:80px">' +
          '<input id="fixture-value"><button id="submit" type="button" style="width:100px;height:30px">Continue</button></form>';
      });
    `);
    const context = {
      browser:browser, browserId:browser.browserId,
      flowId:await PokeToolRuntime.system.uuid(), taskId:task.id,
      cancellationToken:runnerContext.cancellationToken,
      emit:runnerContext.emit
    };
    const steps = [
      {
        id:"open-login", name:"Open fixture login", pageBefore:HOME, pageAfter:LOGIN,
        timeoutMs:3000, retryPolicy:{maxAttempts:1},
        action:async () => {
          await browser.click("#login-button");
          await browser.evaluate(`
            document.querySelector("#submit").addEventListener("click", function () {
              document.title = "Fixture Loading";
              document.body.innerHTML = '<div id="loading" style="width:200px;height:40px">Loading</div>';
              setTimeout(function () {
                document.title = "Fixture Dashboard";
                document.body.innerHTML = '<main id="dashboard" style="width:200px;height:40px">Ready</main>';
              }, 80);
            });
          `);
        }
      },
      {
        id:"submit-fixture", name:"Submit fixture", pageBefore:LOGIN,
        pageAfter:DASHBOARD, allowIntermediate:[LOADING], timeoutMs:4000,
        retryPolicy:{maxAttempts:1}, sensitive:false,
        action:async () => {
          if (task.payload && task.payload.outcome === "maintenance") {
            await browser.evaluate(`
              document.title = "Fixture Maintenance";
              document.body.innerHTML = '<main style="width:200px;height:40px">maintenance</main>';
            `);
          } else {
            await browser.click("#submit");
          }
        }
      }
    ];
    return await product.flow.run(context, steps);
  } finally {
    await PokeToolRuntime.web.safeDestroy(browser);
  }
};
