//
//  CrossModuleTypedThrowsTests.swift
//  swift-splat
//
//  Tests that typed throws works correctly across module boundaries.
//

import SplatTestFixtures
import Testing

@Suite
struct CrossModuleTypedThrowsTests {

    @Test
    func `typed throws propagates across modules`() {
        // This test verifies that when calling a @Splat-generated initializer
        // from a different module, the typed throws information is preserved.
        //
        // If typed throws is NOT working, `error` in the catch block will be
        // `any Error` and the line `error.reason` will fail to compile.

        do {
            _ = try TypedThrowsFixture(isValid: false)
            Issue.record("Should have thrown an error")
        } catch {
            // With typed throws working correctly, `error` should be
            // `TypedThrowsFixture.Error`, not `any Error`.
            // This line will fail to compile if error is `any Error`:
            #expect(error.reason == "Validation failed: isValid was false")
        }
    }

    @Test
    func `typed throws success case`() {
        // Verify the success case still works
        do {
            let fixture = try TypedThrowsFixture(isValid: true)
            #expect(fixture.arguments.isValid == true)
        } catch {
            Issue.record("Should not throw for valid input: \(error)")
        }
    }

    @Test
    func `error type is correct`() {
        // Explicitly verify the error type
        do {
            _ = try TypedThrowsFixture(isValid: false)
            Issue.record("Should have thrown")
        } catch {
            #expect(error.reason.contains("isValid was false"))
        }
    }
}
