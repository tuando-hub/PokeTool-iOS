import XCTest
@testable import PokeTool

final class JumpPlusVerticalSliceTests: XCTestCase {
    @MainActor
    func testEntryCapabilitiesTaskValidationAndNoJumpCharactersStore() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const product=require("/modules/jumpplus/jumpplus-entry");
            let invalid=null;
            try{product.validateTask({id:"bad",mode:"jumpplus.subscribe",account:{email:"a@example.com",password:"p"},input:{}});}
            catch(error){invalid=error.code;}
            const task=product.validateTask({id:"login",mode:"jumpplus.login",
              account:{email:"a@example.com",password:"p"},input:{},options:{}});
            return {version:product.version,modes:product.modes,capabilities:product.capabilities,
              invalid:invalid,allowFinalSubmit:task.options.allowFinalSubmit,
              jumpCS:typeof global.JumpCS};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["version"] as? String, "1.0.0")
        XCTAssertEqual((value["modes"] as? [String])?.count, 4)
        XCTAssertEqual(value["invalid"] as? String, "JUMPPLUS_INVALID_TASK")
        XCTAssertEqual(value["allowFinalSubmit"] as? Bool, false)
        XCTAssertEqual((value["capabilities"] as? [String: Any])?["jumpCharactersStore"] as? Bool, false)
        XCTAssertEqual(value["jumpCS"] as? String, "undefined")
    }

    @MainActor
    func testPageVerificationRequiresURLTitleAndDOM() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const pages=require("/modules/jumpplus/jumpplus-pages");
            const state={url:"https://shonenjumpplus.com/",title:"Shonen Jump Plus",visible:true};
            const browser={url:async()=>state.url,title:async()=>state.title,readyState:async()=>"complete",
              text:async()=>"",exists:async()=>state.visible,
              query:async()=>({visible:state.visible,width:100,height:30}),evaluate:async()=>true};
            const ok=await pages.inspect(browser,pages.pages.HOME);
            state.title="Wrong";const wrongTitle=await pages.inspect(browser,pages.pages.HOME);
            state.title="Shonen Jump Plus";state.visible=false;
            const missingDOM=await pages.inspect(browser,pages.pages.HOME);
            return {ok:ok.ok,wrongTitle:wrongTitle.ok,missingDOM:missingDOM.ok};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["ok"] as? Bool, true)
        XCTAssertEqual(value["wrongTitle"] as? Bool, false)
        XCTAssertEqual(value["missingDOM"] as? Bool, false)
    }

    @MainActor
    func testConfirmationURLValidationAndRedaction() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const confirmation=require("/modules/jumpplus/jumpplus-email-confirmation");
            const security=require("/modules/jumpplus/jumpplus-security");
            const good=confirmation.validateURL("https://shonenjumpplus.com/user_account/signup_registration/fixture_token");
            const bad=[];
            for(const value of ["http://shonenjumpplus.com/user_account/signup_registration/x",
              "https://evil.test/user_account/signup_registration/x",
              "https://shonenjumpplus.com/user_account/signup_registration/x?token=secret"]){
              try{confirmation.validateURL(value);}catch(error){bad.push(error.code);}
            }
            return {good:good,bad:bad,safe:security.safeURL(good+"?token=secret"),
              redacted:security.redact({password:"p",cardNumber:"4111111111111111",email:"a@example.com"})};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["good"] as? String, "https://shonenjumpplus.com/user_account/signup_registration/fixture_token")
        XCTAssertEqual((value["bad"] as? [String])?.count, 3)
        XCTAssertFalse((value["safe"] as? String ?? "").contains("secret"))
        let redacted = try XCTUnwrap(value["redacted"] as? [String: Any])
        XCTAssertEqual(redacted["password"] as? String, "<redacted>")
        XCTAssertEqual(redacted["cardNumber"] as? String, "<redacted>")
        XCTAssertNotEqual(redacted["email"] as? String, "a@example.com")
    }

    @MainActor
    func testPaymentValidationAndDefaultReviewSafety() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const payment=require("/modules/jumpplus/jumpplus-payment");
            const normalized=payment.normalize({cardNumber:"4111 1111 1111 1111",
              expMonth:"2",expYear:"30",securityCode:"123"});
            const context={cancellationToken:{throwIfCancelled:()=>{}}};
            const browser={url:async()=>"https://shonenjumpplus.com/review",title:async()=>"Shonen Jump Plus",
              readyState:async()=>"complete",text:async()=>"",exists:async()=>true,
              query:async()=>({visible:true,width:100,height:30}),evaluate:async()=>true};
            const result=await payment.finalSubmit({browser:browser},
              {options:{allowFinalSubmit:false}},context);
            return {digits:normalized.cardNumber.length,month:normalized.expMonth,year:normalized.expYear,
              status:result.status,productId:result.data.productId};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["digits"] as? Int, 16)
        XCTAssertEqual(value["month"] as? String, "02")
        XCTAssertEqual(value["year"] as? String, "2030")
        XCTAssertEqual(value["status"] as? String, "READY_FOR_FINAL_SUBMIT")
        XCTAssertEqual(value["productId"] as? String, "10834108156675977993")
    }

    @MainActor
    func testFixturesAndSafeJumpPlusEventDelivery() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const fixtures=require("/modules/jumpplus/jumpplus-fixtures");
            let observed=null;
            const id=PokeToolRuntime.events.on("jumpplus.task.started",value=>{observed=value;});
            await PokeToolRuntime.events.emit("jumpplus.task.started",{taskId:"fixture"});
            PokeToolRuntime.events.off(id);
            return {fixtureCount:Object.keys(fixtures).length,hasCard:fixtures.credit.includes("ccNumber"),
              observed:observed};
            """
        )
        let value = try valueObject(response)
        XCTAssertGreaterThanOrEqual(value["fixtureCount"] as? Int ?? 0, 20)
        XCTAssertEqual(value["hasCard"] as? Bool, true)
        XCTAssertEqual((value["observed"] as? [String: Any])?["taskId"] as? String, "fixture")
    }

    @MainActor private func makeRuntime() throws -> JavaScriptRuntime {
        let runtime = try XCTUnwrap(DependencyContainer().runtimeFactory.makeRuntime() as? JavaScriptRuntime)
        XCTAssertEqual(try runtime.start().phase, 9)
        return runtime
    }

    private func valueObject(_ result: String) throws -> [String: Any] {
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        XCTAssertEqual(root["ok"] as? Bool, true, result)
        return try XCTUnwrap(root["value"] as? [String: Any])
    }
}
