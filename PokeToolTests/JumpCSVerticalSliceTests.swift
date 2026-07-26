import XCTest
@testable import PokeTool

final class JumpCSVerticalSliceTests: XCTestCase {
    @MainActor
    func testEntryCapabilitiesAndTaskValidation() async throws {
        let runtime = try makeRuntime(); defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const product=require("/modules/jumpcs/jumpcs-entry"); let invalid=null;
            try{product.validateTask({id:"x",mode:"jumpcs.buy",account:{email:"a@example.com",password:"p"},product:{}});}catch(e){invalid=e.code;}
            const task=product.validateTask({id:"p",mode:"jumpcs.prepareSession",account:{email:"a@example.com",password:"p"}});
            return {version:product.version,modes:product.modes,invalid:invalid,final:task.options.allowFinalSubmit,phone:product.capabilities.phoneRental};
            """
        )
        let value = try object(response)
        XCTAssertEqual(value["version"] as? String, "1.0.0")
        XCTAssertEqual((value["modes"] as? [String])?.count, 6)
        XCTAssertEqual(value["invalid"] as? String, "JUMPCS_INVALID_TASK")
        XCTAssertEqual(value["final"] as? Bool, false)
        XCTAssertEqual(value["phone"] as? String, "requiresConfiguration")
    }

    @MainActor
    func testStoreURLValidationAndPhoneInvariant() async throws {
        let runtime = try makeRuntime(); defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const store=require("/modules/jumpcs/jumpcs-store-url"); const profile=require("/modules/jumpcs/jumpcs-profile");
            const good=store.validate("https://jumpcs.shueisha.co.jp/shop/customer/menu.aspx?subscr_token=fixture"); let bad=null;
            try{store.validate("https://evil.test/?subscr_token=x");}catch(e){bad=e.code;}
            let mismatch=null;try{profile.profilePhone({profile:{phone:"09011112222"}},{phone:"09033334444"});}catch(e){mismatch=e.code;}
            return {safe:store.safe(good.url),bad:bad,mismatch:mismatch,token:good.token};
            """
        )
        let value = try object(response)
        XCTAssertEqual((value["safe"] as? [String:Any])?["tokenPresent"] as? Bool, true)
        XCTAssertEqual(value["bad"] as? String, "JUMPCS_STORE_URL_INVALID")
        XCTAssertEqual(value["mismatch"] as? String, "JUMPCS_PHONE_MISMATCH")
        XCTAssertEqual(value["token"] as? String, "fixture")
    }

    @MainActor
    func testMockGraphQLAuthenticationAndRotatedBearer() async throws {
        let runtime = try makeRuntime(); defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const api=require("/modules/jumpcs/jumpcs-api-client");
            const task={account:{email:"api@example.com",password:"secret"},options:{initialBearer:"guest",mockGraphQL:{
              Login:{data:{login:{userAccount:{databaseId:"id",emailAddress:"api@example.com"}}}},
              CreateCharacterStoreUrl:{data:{createJumpCharactersStoreUrl:{url:"https://jumpcs.shueisha.co.jp/shop/customer/menu.aspx?subscr_token=fixture"}}},
              Logout:{data:{logout:{sessionToken:"rotated"}}}}}};
            const session=await api.authenticate(task);
            return {host:session.store.url.split("/")[2],tokenPresent:Boolean(session.store.token),devicePresent:Boolean(session.deviceId)};
            """
        )
        let value = try object(response)
        XCTAssertEqual(value["host"] as? String, "jumpcs.shueisha.co.jp")
        XCTAssertEqual(value["tokenPresent"] as? Bool, true)
        XCTAssertEqual(value["devicePresent"] as? Bool, true)
    }

    @MainActor
    func testProviderRequiresConfigurationAndMockIsDeterministic() async throws {
        let runtime = try makeRuntime(); defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const provider=require("/modules/jumpcs/jumpcs-phone-provider"); let unavailable=null;
            try{await provider.create({options:{}}).authenticate({},{})}catch(e){unavailable=e.code;}
            const p=provider.create({options:{mockPhoneProvider:{phone:"090-1234-5678",pkey:"p",otp:"123456"}}});
            const order=await p.orderNumber();const number=await p.waitNumber(order);const otp=await p.waitOtp(order);
            return {unavailable:unavailable,phone:number.phone,pkey:number.pkey,otp:otp};
            """
        )
        let value = try object(response)
        XCTAssertEqual(value["unavailable"] as? String, "JUMPCS_PHONE_PROVIDER_UNAVAILABLE")
        XCTAssertEqual(value["phone"] as? String, "09012345678")
        XCTAssertEqual(value["pkey"] as? String, "p")
        XCTAssertEqual(value["otp"] as? String, "123456")
    }

    @MainActor
    func testResultRedactionAndDefaultFinalSubmit() async throws {
        let runtime = try makeRuntime(); defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const result=require("/modules/jumpcs/jumpcs-result"); const payment=require("/modules/jumpcs/jumpcs-checkout");
            const r=result.make({id:"x",mode:"jumpcs.buy",account:{email:"private@example.com"}},"READY_FOR_FINAL_SUBMIT",null,null,Date.now(),{card:"4111",otp:"123456",orderId:"1234"},{});
            return {status:r.status,account:r.accountIdentifier,data:r.data};
            """
        )
        let value = try object(response)
        XCTAssertEqual(value["status"] as? String, "READY_FOR_FINAL_SUBMIT")
        XCTAssertFalse((value["account"] as? String ?? "").contains("private@"))
        let data = try XCTUnwrap(value["data"] as? [String:Any])
        XCTAssertEqual(data["card"] as? String, "<redacted>")
        XCTAssertEqual(data["otp"] as? String, "<redacted>")
    }

    @MainActor private func makeRuntime() throws -> JavaScriptRuntime {
        let runtime = try XCTUnwrap(DependencyContainer().runtimeFactory.makeRuntime() as? JavaScriptRuntime)
        XCTAssertEqual(try runtime.start().phase, 9)
        return runtime
    }
    private func object(_ result:String) throws -> [String:Any] { let root=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(result.utf8)) as? [String:Any]); XCTAssertEqual(root["ok"] as? Bool,true,result); return try XCTUnwrap(root["value"] as? [String:Any]) }
}
