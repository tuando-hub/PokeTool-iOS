import XCTest
@testable import PokeTool

final class PokemonVerticalSliceTests: XCTestCase {
    @MainActor
    func testEntryModesCapabilitiesAndTaskValidation() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const pokemon=require("/modules/pokemon/pokemon-entry");
            let invalid=null;
            try{pokemon.validateTask({id:"x",mode:"pokemon.buy",account:{email:"a@example.com",password:"p"},input:{}});}
            catch(error){invalid=error.code;}
            const task=pokemon.validateTask({
              id:"buy",mode:"pokemon.buy",account:{email:"a@example.com",password:"p"},
              input:{productURL:"https://www.pokemoncenter-online.com/product/test"},
              options:{}
            });
            return {version:pokemon.version,modes:pokemon.modes,capabilities:pokemon.capabilities,
              invalid:invalid,allowFinalSubmit:task.options.allowFinalSubmit};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["version"] as? String, "1.0.0")
        XCTAssertEqual((value["modes"] as? [String])?.count, 6)
        XCTAssertEqual(value["invalid"] as? String, "POKEMON_INVALID_TASK")
        XCTAssertEqual(value["allowFinalSubmit"] as? Bool, false)
        XCTAssertEqual((value["capabilities"] as? [String: Any])?["pageVerification"] as? String, "url+title+dom")
    }

    @MainActor
    func testPokemonPageVerificationRequiresURLTitleAndDOM() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const pages=require("/modules/pokemon/pokemon-pages");
            const state={url:"https://www.pokemoncenter-online.com/login/",
              title:"Pokemon Center Online",visible:true};
            const browser={
              url:async()=>state.url,title:async()=>state.title,readyState:async()=>"complete",
              text:async()=>"",exists:async()=>state.visible,
              query:async()=>({visible:state.visible,width:100,height:30})
            };
            const ok=await pages.inspect(browser,pages.pages.LOGIN);
            state.title="Wrong title";
            const wrongTitle=await pages.inspect(browser,pages.pages.LOGIN);
            state.title="Pokemon Center Online";state.visible=false;
            const missingDOM=await pages.inspect(browser,pages.pages.LOGIN);
            return {ok:ok.ok,wrongTitle:wrongTitle.ok,missingDOM:missingDOM.ok,
              missing:missingDOM.missingSignals};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["ok"] as? Bool, true)
        XCTAssertEqual(value["wrongTitle"] as? Bool, false)
        XCTAssertEqual(value["missingDOM"] as? Bool, false)
        XCTAssertFalse((value["missing"] as? [String] ?? []).isEmpty)
    }

    @MainActor
    func testOTPConfigurationMockAndSafeResultRedaction() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const otp=require("/modules/pokemon/pokemon-otp-provider");
            const resultModule=require("/modules/pokemon/pokemon-result");
            let unconfigured=null;
            try{await otp.wait({mode:"Create"},{otp:{},cancellationToken:{throwIfCancelled:()=>{}}});}
            catch(error){unconfigured={code:error.code,diagnostics:error.diagnostics};}
            const mock=await otp.wait({mode:"Lottery"},{
              otp:{mockResult:{type:"numericOTP",value:"123456"}},
              cancellationToken:{throwIfCancelled:()=>{}}
            });
            const safe=resultModule.make(
              {id:"x",mode:"pokemon.lottery",account:{email:"private@example.com"}},
              "ENTERED",null,null,Date.now(),{otp:"123456",token:"secret"},{}
            );
            return {unconfigured:unconfigured,mockType:mock.type,
              otpRedacted:safe.data.otp,tokenRedacted:safe.data.token,
              account:safe.accountIdentifier};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual((value["unconfigured"] as? [String: Any])?["code"] as? String, "POKEMON_OTP_FAILED")
        XCTAssertEqual(value["mockType"] as? String, "numericOTP")
        XCTAssertEqual(value["otpRedacted"] as? String, "<redacted>")
        XCTAssertEqual(value["tokenRedacted"] as? String, "<redacted>")
        XCTAssertFalse((value["account"] as? String ?? "").contains("private@"))
    }

    @MainActor
    func testCheckResultParserAndEventPrefix() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let response = try await runtime.runAsyncTestScript(
            """
            const parser=require("/modules/pokemon/pokemon-check-result-mode");
            let observed=null;
            const id=PokeToolRuntime.events.on("pokemon.task.started",value=>{observed=value;});
            await PokeToolRuntime.events.emit("pokemon.task.started",{taskId:"fixture"});
            PokeToolRuntime.events.off(id);
            return {won:parser.statusFromText("selected won"),lost:parser.statusFromText("not selected lost"),
              pending:parser.statusFromText("application in progress"),observed:observed};
            """
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["won"] as? String, "WON")
        XCTAssertEqual(value["lost"] as? String, "LOST")
        XCTAssertEqual(value["pending"] as? String, "PENDING")
        XCTAssertEqual((value["observed"] as? [String: Any])?["taskId"] as? String, "fixture")
    }

    @MainActor private func makeRuntime() throws -> JavaScriptRuntime {
        let runtime = try XCTUnwrap(DependencyContainer().runtimeFactory.makeRuntime() as? JavaScriptRuntime)
        XCTAssertEqual(try runtime.start().phase, 8)
        return runtime
    }
    private func valueObject(_ result: String) throws -> [String: Any] {
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        XCTAssertEqual(root["ok"] as? Bool, true, result)
        return try XCTUnwrap(root["value"] as? [String: Any])
    }
}
