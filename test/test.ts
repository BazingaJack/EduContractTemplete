import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {expect} from "chai";
import {ethers} from "hardhat";
import { ContractFactory } from "ethers";

describe("Education Template Contract deployed", async function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployContracts() {
        // Contracts are deployed using the first signer/account by default
        const [deployer, undergraduate, postgraduate, phd , teacher, manangement] = await ethers.getSigners();
        const EduTemplate = await ethers.getContractFactory("EduTemplate");
        const edutemplate = await EduTemplate.deploy();

        return {
            edutemplate,
            accounts : {deployer, undergraduate, postgraduate, phd, teacher, manangement}
        }
    }

    async function deployAndRegisterAll() {
        const {edutemplate,accounts} = await loadFixture(deployContracts);

        await edutemplate.connect(accounts.deployer).stuRegister(accounts.undergraduate.address,"stu1",20,"cs","undergraduate");
        await edutemplate.connect(accounts.deployer).stuRegister(accounts.postgraduate.address,"stu2",25,"cs","postgraduate");
        await edutemplate.connect(accounts.deployer).stuRegister(accounts.phd.address,"stu3",28,"cs","phd");
        await edutemplate.connect(accounts.deployer).thrRegister(accounts.teacher.address,"thr1",30,"cs");
        await edutemplate.connect(accounts.deployer).mgrRegister(accounts.manangement.address,"mgr1","cs");

        return {
            edutemplate,
            accounts
        }
    }

    describe("Role test",async function () {
        it("Should register student successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployContracts);
            await edutemplate.connect(accounts.deployer).stuRegister(accounts.undergraduate.address,"stu1",20,"cs","undergraduate");
            expect (await edutemplate.connect(accounts.deployer).checkRole(accounts.undergraduate.address,0)).to.equal(true);
        })
        it("Should register teacher successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployContracts);
            await edutemplate.connect(accounts.deployer).thrRegister(accounts.teacher.address,"thr1",30,"cs");
            expect (await edutemplate.connect(accounts.deployer).checkRole(accounts.teacher.address,1)).to.equal(true);
        })
        it("Should register manangement successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployContracts);
            await edutemplate.connect(accounts.deployer).mgrRegister(accounts.manangement.address,"mgr1","cs");
            expect (await edutemplate.connect(accounts.deployer).checkRole(accounts.manangement.address,2)).to.equal(true);
        })
    })

    describe("Student relevant basic function test",async function () {
        it("Should initialize thesis successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher.address,"Title","Content");
            const nextId = await edutemplate.nextThesisId();
            expect (nextId).to.be.equal(1);
            const title = (await edutemplate.thesisSets(0)).title;
            expect (title).to.be.equal("Title");
            const content = (await edutemplate.thesisSets(0)).content;
            expect (content).to.be.equal("Content");
        })

        it("Should modify thesis successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            const content = (await edutemplate.thesisSets(0)).content;
            expect (content).to.be.equal("Modified Content");
        })

        it("Should submit thesis successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.undergraduate).thesisSubmit();
            const status = (await edutemplate.thesisSets(0)).status;
            expect (status).to.be.equal(1);
        })

    })

});
