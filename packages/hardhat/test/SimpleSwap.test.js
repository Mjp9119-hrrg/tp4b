const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleSwap Contract", function () {
  let tokenA, tokenB, simpleSwap;
  let owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    const TokenFactory = await ethers.getContractFactory("MyTokenA");
    tokenA = await TokenFactory.deploy();
    tokenB = await TokenFactory.deploy();
    await tokenA.waitForDeployment();
    await tokenB.waitForDeployment();

    const SwapFactory = await ethers.getContractFactory("SimpleSwap");
    simpleSwap = await SwapFactory.deploy();
    await simpleSwap.waitForDeployment();

    // Mint tokens to users
    const amount = ethers.parseEther("1000");
    await tokenA.mint(owner.address, amount);
    await tokenB.mint(owner.address, amount);
    await tokenA.mint(user.address, amount);
    await tokenB.mint(user.address, amount);

    // Approve tokens to SimpleSwap
    await tokenA.connect(owner).approve(simpleSwap.getAddress(), amount);
    await tokenB.connect(owner).approve(simpleSwap.getAddress(), amount);
    await tokenA.connect(user).approve(simpleSwap.getAddress(), amount);
    await tokenB.connect(user).approve(simpleSwap.getAddress(), amount);

    // Add initial liquidity
/*    await simpleSwap.connect(owner).addLiquidity(
      tokenA.getAddress(),
      tokenB.getAddress(),
      ethers.parseEther("500"),
      ethers.parseEther("500"),
      ethers.parseEther("300"),
      ethers.parseEther("300"),
      owner.address,
      Math.floor(Date.now() / 1000) + 120
    );
*/
        // Add initial liquidity with furedeadline cos we are having issues with the deadline
    const futureDeadline = Math.floor(Date.now() / 1000) + 1200; // 20 minutos en el futuro
    await simpleSwap.connect(owner).addLiquidity(
      tokenA.getAddress(),
      tokenB.getAddress(),
      ethers.parseEther("500"),
      ethers.parseEther("500"),
      ethers.parseEther("300"),
      ethers.parseEther("300"),
      owner.address,
      futureDeadline
    );

  });

  describe("addLiquidity", function () {
    it("should add liquidity successfully", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 1260;
      const tx = await simpleSwap.connect(user).addLiquidity(
        tokenA.getAddress(),
        tokenB.getAddress(),
        ethers.parseEther("100"),
        ethers.parseEther("100"),
        ethers.parseEther("50"),
        ethers.parseEther("50"),
        user.address,
        deadline
      );
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment?.name === "LiquidityAdded");
      expect(event).to.not.be.undefined;
    });

    it("should revert if deadline is expired", async function () {
      const expiredDeadline = Math.floor(Date.now() / 1000) - 10;
      await expect(
        simpleSwap.connect(user).addLiquidity(
          tokenA.getAddress(),
          tokenB.getAddress(),
          ethers.parseEther("100"),
          ethers.parseEther("100"),
          ethers.parseEther("50"),
          ethers.parseEther("50"),
          user.address,
          expiredDeadline
        )
      ).to.be.revertedWith("TimeIsOver");
    });

    it("should fail if amountAMin is too high", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 1260;
      await expect(
        simpleSwap.connect(user).addLiquidity(
          tokenA.getAddress(),
          tokenB.getAddress(),
          ethers.parseEther("100"),
          ethers.parseEther("100"),
          ethers.parseEther("1000"),
          ethers.parseEther("100"),
          user.address,
          deadline
        )
      ).to.be.revertedWith("Amount A is too small");
    });
  });

  describe("swapExactTokensForTokens", function () {
    it("should swap tokens successfully", async function () {
      const amountIn = ethers.parseEther("10");
      const deadline = Math.floor(Date.now() / 1000) + 1260;
      const path = [tokenA.getAddress(), tokenB.getAddress()];

      const reserveA = await tokenA.balanceOf(simpleSwap.getAddress());
      const reserveB = await tokenB.balanceOf(simpleSwap.getAddress());
      const expectedOut = (amountIn * reserveB) / (amountIn + reserveA);

      const tx = await simpleSwap.connect(user).swapExactTokensForTokens(
        amountIn,
        expectedOut,
        path,
        user.address,
        deadline
      );
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment?.name === "TokensSwapped");
      expect(event).to.not.be.undefined;
    });

    it("should fail on invalid path length", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 1260;
      await expect(
        simpleSwap.connect(user).swapExactTokensForTokens(
          ethers.parseEther("10"),
          0,
          [tokenA.getAddress()],
          user.address,
          deadline
        )
      ).to.be.revertedWith("Invalid path length");
    });
  });

  describe("removeLiquidity", function () {
    it("should remove liquidity successfully", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 1260;
      const liquidity = await simpleSwap.balanceOf(owner.address);
      const tx = await simpleSwap.connect(owner).removeLiquidity(
        tokenA.getAddress(),
        tokenB.getAddress(),
        liquidity,
        ethers.parseEther("100"),
        ethers.parseEther("100"),
        owner.address,
        deadline
      );
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment?.name === "LiquidityRemoved");
      expect(event).to.not.be.undefined;
    });

    it("should fail if caller is not token holder", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 1260;
      const liquidity = await simpleSwap.balanceOf(owner.address);
      await expect(
        simpleSwap.connect(user).removeLiquidity(
          tokenA.getAddress(),
          tokenB.getAddress(),
          liquidity,
          ethers.parseEther("100"),
          ethers.parseEther("100"),
          owner.address,
          deadline
        )
      ).to.be.revertedWith("Only liquidity provider can burn their tokens");
    });
  });

  describe("getPrice", function () {
    it("should return correct price", async function () {
      const reserveA = await tokenA.balanceOf(simpleSwap.getAddress());
      const reserveB = await tokenB.balanceOf(simpleSwap.getAddress());
      const price = await simpleSwap.getPrice(
        tokenA.getAddress(),
        tokenB.getAddress()
      );
      //const expectedPrice = (reserveB * 1e18n) / reserveA;
      const expectedPrice = reserveB * BigInt("1000000000000000000") / reserveA;
      expect(price).to.equal(expectedPrice);
    });

    it("should fail if reserves are zero", async function () {
      const SwapFactory = await ethers.getContractFactory("SimpleSwap");
      const freshSwap = await SwapFactory.deploy();
      await freshSwap.waitForDeployment();
      await expect(
        freshSwap.getPrice(tokenA.getAddress(), tokenB.getAddress())
      ).to.be.revertedWith("Insufficient reserves for price calculation");
    });

    it("should fail if tokens are the same", async function () {
      await expect(
        simpleSwap.getPrice(tokenA.getAddress(), tokenA.getAddress())
      ).to.be.revertedWith("Cannot calculate price for the same token");
    });
  });
});