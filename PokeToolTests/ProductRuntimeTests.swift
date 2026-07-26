import XCTest
@testable import PokeTool

final class ProductRuntimeTests: XCTestCase {
    @MainActor
    func testPageGuardMultiSignalConfidenceAndSafeDiagnostics() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const guard = require("/runtime/page-guard");
            const state = {
              url:"https://fixture.invalid/home", title:"Fixture Home",
              readyState:"complete", text:"Welcome password=hidden",
              visible:true, exists:true
            };
            const browser = {
              url:async()=>state.url, title:async()=>state.title,
              readyState:async()=>state.readyState, text:async()=>state.text,
              exists:async()=>state.exists,
              query:async()=>({visible:state.visible,width:100,height:20})
            };
            const descriptor = {
              name:"Home",
              url:{type:"contains",value:"/home"},
              title:{type:"includesAny",values:["Home","Start"]},
              selectors:[{name:"marker",selector:"#home",state:"visible"}],
              text:{includes:"Welcome",excludes:"maintenance"},
              readyState:["interactive","complete"],
              customPredicate:snapshot=>snapshot.url.startsWith("https://fixture.invalid"),
              confidencePolicy:{type:"minimumMatches",minimum:5},
              captureText:true
            };
            const matched = await guard.inspect(browser, descriptor);
            state.visible = false;
            const hidden = await guard.inspect(browser, {
              name:"Hidden", selectors:[{selector:"#home",state:"visible"}]
            });
            let invalidCode = null;
            try { await guard.inspect(browser, {name:"Invalid"}); }
            catch (error) { invalidCode = error.code; }
            return {matched,hidden,invalidCode};
            """
        )
        let value = try valueObject(result)
        let matched = try XCTUnwrap(value["matched"] as? [String: Any])
        XCTAssertEqual(matched["ok"] as? Bool, true)
        XCTAssertGreaterThanOrEqual((matched["matchedSignals"] as? [String])?.count ?? 0, 5)
        let excerpt = ((matched["snapshot"] as? [String: Any])?["textExcerpt"] as? String) ?? ""
        XCTAssertFalse(excerpt.contains("hidden"))
        XCTAssertEqual((value["hidden"] as? [String: Any])?["ok"] as? Bool, false)
        XCTAssertEqual(value["invalidCode"] as? String, "FLOW_PRECONDITION_FAILED")
    }

    @MainActor
    func testTransitionRetryIntermediateAndExhaustion() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const transition = require("/runtime/transition-guard");
            let state = {url:"fixture://home",title:"Home",marker:"home"};
            const browser = {
              url:async()=>state.url,title:async()=>state.title,readyState:async()=>"complete",
              text:async()=>state.marker,
              exists:async selector=>selector==="#" + state.marker,
              query:async selector=>({visible:selector==="#" + state.marker,width:100,height:20}),
              reload:async()=>{}
            };
            const page = (name,marker)=>({
              name:name,title:{type:"exact",value:name},
              selectors:[{selector:"#" + marker,state:"visible"}]
            });
            let attempts = 0;
            const success = await transition.perform({
              browser,name:"fixture transition",from:page("Home","home"),
              to:page("Dashboard","dashboard"),allowIntermediate:[page("Loading","loading")],
              timeoutMs:2000,retryPolicy:{maxAttempts:2,delayMs:20,retryOn:["ACTION_FAILED"]},
              action:async()=>{
                attempts += 1;
                if(attempts===1){const e=new Error("first");e.code="ACTION_FAILED";throw e;}
                state={url:"fixture://loading",title:"Loading",marker:"loading"};
                setTimeout(()=>{state={url:"fixture://dashboard",title:"Dashboard",marker:"dashboard"};},40);
              }
            });
            let exhausted = null;
            state={url:"fixture://home",title:"Home",marker:"home"};
            try {
              await transition.perform({
                browser,from:page("Home","home"),to:page("Dashboard","dashboard"),
                timeoutMs:300,retryPolicy:{maxAttempts:2,delayMs:10},
                action:async()=>{}
              });
            } catch(error) { exhausted=error.code; }
            return {attempts,success,exhausted};
            """
        )
        let value = try valueObject(result)
        XCTAssertEqual(value["attempts"] as? Int, 2)
        XCTAssertEqual((value["success"] as? [String: Any])?["ok"] as? Bool, true)
        XCTAssertEqual(value["exhausted"] as? String, "RETRY_EXHAUSTED")
    }

    @MainActor
    func testSequentialRunnerSummaryFailureContinueAndCancellation() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const product = require("/modules/product/product-entry");
            product.runner.reset();
            product.runner.configure({stopOnError:false,taskTimeoutMs:1000});
            const order=[];
            const summary=await product.runner.start([
              {id:"a",mode:"fixture"},{id:"b",mode:"fixture"},{id:"c",mode:"fixture"}
            ],async task=>{
              order.push(task.id);
              if(task.id==="b"){const e=new Error("fixture failure");e.code="ACTION_FAILED";throw e;}
              return {id:task.id};
            });
            product.runner.reset();
            const pending=product.runner.start([
              {id:"stop-a",mode:"fixture"},{id:"stop-b",mode:"fixture"}
            ],async(task,context)=>{
              await PokeToolRuntime.system.sleep(100);
              context.cancellationToken.throwIfCancelled();
              return task.id;
            });
            setTimeout(()=>product.runner.stop("test stop"),20);
            const cancelled=await pending;
            return {summary,order,cancelled};
            """
        )
        let value = try valueObject(result)
        let summary = try XCTUnwrap(value["summary"] as? [String: Any])
        XCTAssertEqual(summary["succeeded"] as? Int, 2)
        XCTAssertEqual(summary["failed"] as? Int, 1)
        XCTAssertEqual(value["order"] as? [String], ["a", "b", "c"])
        let cancelled = try XCTUnwrap(value["cancelled"] as? [String: Any])
        XCTAssertEqual(cancelled["cancelled"] as? Int, 1)
        XCTAssertEqual(cancelled["total"] as? Int, 2)
        XCTAssertEqual(cancelled["skipped"] as? Int, 1)
    }

    @MainActor
    func testProductFixtureFlowEndToEnd() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let tasks = """
        [
          {"id":"success","mode":"fixture","payload":{"outcome":"success"}},
          {"id":"maintenance","mode":"fixture","payload":{"outcome":"maintenance"}}
        ]
        """
        let response = try await runtime.startProductRun(
            tasksJSON: tasks,
            executorModuleID: "/modules/fixtures/product-flow-executor"
        )
        let value = try valueObject(response)
        XCTAssertEqual(value["total"] as? Int, 2)
        XCTAssertEqual(value["succeeded"] as? Int, 1)
        XCTAssertEqual(value["failed"] as? Int, 1)
        let results = try XCTUnwrap(value["results"] as? [[String: Any]])
        XCTAssertEqual(results[1]["status"] as? String, "failed")
        XCTAssertEqual(
            (results[1]["error"] as? [String: Any])?["code"] as? String,
            "UNEXPECTED_PAGE",
            response
        )
    }

    @MainActor
    func testProductCapabilitiesAndNoWebsiteBusinessModules() throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        XCTAssertEqual(runtime.evaluateForTesting("require('/modules/product/product-entry').version")?.toString(), "1.0.0")
        XCTAssertEqual(
            runtime.evaluateForTesting("require('/modules/product/product-entry').capabilities.verifiedTransitions")?.toBool(),
            true
        )
        for name in ["OTP", "Pokemon", "Jump", "Amazon"] {
            XCTAssertEqual(runtime.evaluateForTesting("typeof \(name)")?.toString(), "undefined")
        }
    }

    @MainActor
    private func makeRuntime() throws -> JavaScriptRuntime {
        let runtime = try XCTUnwrap(
            DependencyContainer().runtimeFactory.makeRuntime() as? JavaScriptRuntime
        )
        XCTAssertEqual(try runtime.start().phase, 8)
        return runtime
    }

    private func valueObject(_ result: String) throws -> [String: Any] {
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        XCTAssertEqual(root["ok"] as? Bool, true, result)
        return try XCTUnwrap(root["value"] as? [String: Any])
    }
}
