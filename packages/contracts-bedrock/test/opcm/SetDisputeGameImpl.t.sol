// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { IDisputeGame } from "interfaces/dispute/IDisputeGame.sol";
import { IDisputeGameFactory } from "interfaces/dispute/IDisputeGameFactory.sol";
import { GameType } from "src/dispute/lib/Types.sol";
import { SetDisputeGameImpl, SetDisputeGameImplInput } from "scripts/deploy/SetDisputeGameImpl.s.sol";
import { DisputeGameFactory } from "src/dispute/DisputeGameFactory.sol";
import { Proxy } from "src/universal/Proxy.sol";

contract SetDisputeGameImplInput_Test is Test {
    SetDisputeGameImplInput input;

    function setUp() public {
        input = new SetDisputeGameImplInput();
    }

    function test_getters_whenNotSet_reverts() public {
        vm.expectRevert("SetDisputeGameImplInput: not set");
        input.factory();

        vm.expectRevert("SetDisputeGameImplInput: not set");
        input.impl();

        // gameType doesn't revert when not set, returns 0
        assertEq(input.gameType(), 0);
    }

    function test_set_succeeds() public {
        address factory = makeAddr("factory");
        address impl = makeAddr("impl");
        uint32 gameType = 1;

        vm.etch(factory, hex"01");
        vm.etch(impl, hex"01");

        input.set(input.factory.selector, factory);
        input.set(input.impl.selector, impl);
        input.set(input.gameType.selector, gameType);

        assertEq(address(input.factory()), factory);
        assertEq(address(input.impl()), impl);
        assertEq(input.gameType(), gameType);
    }

    function test_set_withZeroAddress_reverts() public {
        vm.expectRevert("SetDisputeGameImplInput: cannot set zero address");
        input.set(input.factory.selector, address(0));

        vm.expectRevert("SetDisputeGameImplInput: cannot set zero address");
        input.set(input.impl.selector, address(0));
    }

    function test_set_withInvalidSelector_reverts() public {
        vm.expectRevert("SetDisputeGameImplInput: unknown selector");
        input.set(bytes4(0xdeadbeef), makeAddr("test"));

        vm.expectRevert("SetDisputeGameImplInput: unknown selector");
        input.set(bytes4(0xdeadbeef), uint32(1));
    }
}

contract SetDisputeGameImpl_Test is Test {
    SetDisputeGameImpl script;
    SetDisputeGameImplInput input;
    IDisputeGameFactory factory;
    address mockImpl;
    uint32 gameType;

    function setUp() public {
        script = new SetDisputeGameImpl();
        input = new SetDisputeGameImplInput();
        DisputeGameFactory impl = new DisputeGameFactory();

        // Needs to be a proxy to properly initialize
        Proxy proxy = new Proxy(address(1));
        vm.prank(address(1));
        proxy.upgradeToAndCall(address(impl), abi.encodeCall(impl.initialize, address(this)));
        factory = IDisputeGameFactory(address(proxy));

        mockImpl = makeAddr("impl");
        gameType = 999;
    }

    function test_run_succeeds() public {
        input.set(input.factory.selector, address(factory));
        input.set(input.impl.selector, mockImpl);
        input.set(input.gameType.selector, gameType);

        script.run(input);
    }

    function test_run_whenImplAlreadySet_reverts() public {
        input.set(input.factory.selector, address(factory));
        input.set(input.impl.selector, mockImpl);
        input.set(input.gameType.selector, gameType);

        // First run should succeed
        script.run(input);

        // Subsequent runs should revert
        vm.expectRevert("SDGI-10");
        script.run(input);
    }

    function test_assertValid_whenNotValid_reverts() public {
        input.set(input.factory.selector, address(factory));
        input.set(input.impl.selector, mockImpl);
        input.set(input.gameType.selector, gameType);

        // First run should succeed
        script.run(input);

        vm.broadcast(address(this));
        factory.setImplementation(GameType.wrap(gameType), IDisputeGame(address(0)));

        vm.expectRevert("SDGI-20");
        script.assertValid(input);
    }
}
