import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {expect} from "chai";
import {ethers} from "hardhat";
import { ContractFactory } from "ethers";
import { access } from "../typechain-types/@openzeppelin/contracts";

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

    async function deployAndRegisterMoreTeachers() {
        const [deployer, undergraduate, postgraduate, phd, teacher1, teacher2, teacher3, teacher4, teacher5, teacher6, manangement] = await ethers.getSigners();
        const EduTemplate = await ethers.getContractFactory("EduTemplate");
        const edutemplate = await EduTemplate.deploy();

        await edutemplate.connect(deployer).stuRegister(undergraduate.address,"stu1",20,"cs","undergraduate");
        await edutemplate.connect(deployer).stuRegister(postgraduate.address,"stu2",25,"cs","postgraduate");
        await edutemplate.connect(deployer).stuRegister(phd.address,"stu3",28,"cs","phd");
        await edutemplate.connect(deployer).thrRegister(teacher1.address,"thr1",30,"cs");
        await edutemplate.connect(deployer).thrRegister(teacher2.address,"thr2",30,"cs");
        await edutemplate.connect(deployer).thrRegister(teacher3.address,"thr3",30,"cs");
        await edutemplate.connect(deployer).thrRegister(teacher4.address,"thr4",30,"cs");
        await edutemplate.connect(deployer).thrRegister(teacher5.address,"thr5",30,"cs");
        await edutemplate.connect(deployer).thrRegister(teacher6.address,"thr6",30,"cs");
        await edutemplate.connect(deployer).mgrRegister(manangement.address,"mgr1","cs");
    
        return {
            edutemplate,
            accounts : {deployer, undergraduate, postgraduate, phd, teacher1, teacher2, teacher3, teacher4, teacher5, teacher6, manangement}
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

    describe("Teacher relevant basic function test",async function () {
        it("Should register course successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            const nextId = await edutemplate.nextCourseId();
            expect (nextId).to.be.equal(1);
            const coursename = (await edutemplate.courses(0)).name;
            expect (coursename).to.be.equal("Course1");
            const credit = (await edutemplate.courses(0)).credit;
            expect (credit).to.be.equal(2);
        })

        it("Should select course successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            await edutemplate.connect(accounts.undergraduate).selectCourse(0);
            const res = await edutemplate.courseStuSets(0,accounts.undergraduate.address);
            expect (res).to.be.equal(true);
        })

        it("Should record scores successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            await edutemplate.connect(accounts.undergraduate).selectCourse(0);
            await edutemplate.connect(accounts.postgraduate).selectCourse(0);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.undergraduate.address,0,90);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.postgraduate.address,0,50);
            const status1 = (await edutemplate.stuSets(accounts.undergraduate.address)).status;
            const status2 = (await edutemplate.stuSets(accounts.postgraduate.address)).status;
            expect (status1).to.be.equal(true);
            expect (status2).to.be.equal(false);
            const average1 = (await edutemplate.stuSets(accounts.undergraduate.address)).averageGrade;
            const average2 = (await edutemplate.stuSets(accounts.postgraduate.address)).averageGrade;
            expect (average1).to.be.equal(90);
            expect (average2).to.be.equal(50);
            const totalCredit1 = (await edutemplate.stuSets(accounts.undergraduate.address)).totalCredit;
            const totalCredit2 =(await edutemplate.stuSets(accounts.postgraduate.address)).totalCredit;
            expect (totalCredit1).to.be.equal(2);
            expect (totalCredit2).to.be.equal(2);
            const grade1 = (await edutemplate.stuGrades(accounts.undergraduate.address,0));
            const grade2 =(await edutemplate.stuGrades(accounts.postgraduate.address,0));
            expect (grade1).to.be.equal(90);
            expect (grade2).to.be.equal(50);
        })

        it("Should be reverted because teacher couldn't review his student's thesis",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.undergraduate).thesisSubmit();
            await expect (edutemplate.connect(accounts.teacher).reviewThesis(accounts.undergraduate.address,3)).to.be.revertedWith("Error: You can't review your student's thesis.");
        })

        it("Should review thesis successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.undergraduate).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.undergraduate.address,3);
            const teacherAddress = (await edutemplate.thesisResults(0,0)).thrAddr;
            const res = (await edutemplate.thesisResults(0,0)).result;
            expect (teacherAddress).to.be.equal(accounts.teacher2.address);
            expect (res).to.be.equal(3);
        })

    })

    describe("Manangement relevant basic function test",async function () {
        it("Should add scholarship successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.manangement).addScholarship("scholarship1",10000);
            const name = (await edutemplate.scholarships(0)).name;
            const amount = (await edutemplate.scholarships(0)).amount;
            expect (name).to.be.equal("scholarship1");
            expect (amount).to.be.equal(10000);
            expect (await edutemplate.nextScholarshipId()).to.be.equal(1);
        })
        
        it("Should apply scholarship successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            await edutemplate.connect(accounts.undergraduate).selectCourse(0);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.undergraduate.address,0,90);
            await edutemplate.connect(accounts.manangement).addScholarship("scholarship1",10000);
            await edutemplate.connect(accounts.undergraduate).applyScholarship(0);
            const num = (await edutemplate.scholarships(0)).applyernum;
            expect (num).to.be.equal(1);
            const applyer = await edutemplate.scholarshipApplyers(0,0);
            expect (applyer).to.be.equal(accounts.undergraduate.address);
            const grade = (await edutemplate.applyList(0,accounts.undergraduate.address));
            expect (grade).to.be.equal(90);
        })

        it("Should choose candidate successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            await edutemplate.connect(accounts.undergraduate).selectCourse(0);
            await edutemplate.connect(accounts.postgraduate).selectCourse(0);
            await edutemplate.connect(accounts.phd).selectCourse(0);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.undergraduate.address,0,90);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.postgraduate.address,0,80);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.phd.address,0,95);
            await edutemplate.connect(accounts.manangement).addScholarship("scholarship1",10000);
            await edutemplate.connect(accounts.undergraduate).applyScholarship(0);
            await edutemplate.connect(accounts.postgraduate).applyScholarship(0);
            await edutemplate.connect(accounts.phd).applyScholarship(0);
            await edutemplate.connect(accounts.manangement).chooseCandidate(0);
            const winer = (await edutemplate.scholarships(0)).winer;
            const status = (await edutemplate.scholarships(0)).status;
            expect (winer).to.be.equal(accounts.phd.address);
            expect (status).to.be.equal(1);
        })

        it("Should distribute scholarship successfully",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            await edutemplate.connect(accounts.undergraduate).selectCourse(0);
            await edutemplate.connect(accounts.postgraduate).selectCourse(0);
            await edutemplate.connect(accounts.phd).selectCourse(0);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.undergraduate.address,0,90);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.postgraduate.address,0,80);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.phd.address,0,95);
            await edutemplate.connect(accounts.manangement).addScholarship("scholarship1",10000);
            await edutemplate.connect(accounts.undergraduate).applyScholarship(0);
            await edutemplate.connect(accounts.postgraduate).applyScholarship(0);
            await edutemplate.connect(accounts.phd).applyScholarship(0);
            await edutemplate.connect(accounts.manangement).chooseCandidate(0);
            await edutemplate.connect(accounts.manangement).distributeScholarship(0);
            const amount = (await edutemplate.stuSets(accounts.phd.address)).scholarshipAmount;
            const status = (await edutemplate.scholarships(0)).status;
            expect (amount).to.be.equal(10000);
            expect (status).to.be.equal(2);
        })
        
    })

    describe("Graduation qualification review relevant test",async function () {
        it("Should be reverted because grade verification failed",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterAll);
            await edutemplate.connect(accounts.teacher).registerCourse("Course1",2);
            await edutemplate.connect(accounts.undergraduate).selectCourse(0);
            await edutemplate.connect(accounts.teacher).recordScores(accounts.undergraduate.address,0,50);
            await expect (edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.undergraduate.address)).to.be.revertedWith("Error: Invalid status.");
        })

        it("Should be reverted because thesis hasn't been reviewed totally",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.undergraduate).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.undergraduate.address,2);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.undergraduate.address,0);
            await expect (edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.undergraduate.address)).to.be.revertedWith("Error: Your thesis hasn't been reviewed yet.");
        })

        it("Should be reverted because undergraduate's thesis hasn't reached the standard",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.undergraduate).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.undergraduate.address,2);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.undergraduate.address,0);
            await edutemplate.connect(accounts.teacher4).reviewThesis(accounts.undergraduate.address,1);
            await edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.undergraduate.address);
            const status = (await edutemplate.stuSets(accounts.undergraduate.address)).isGraduated;
            expect (status).to.be.equal(false);
        })

        it("Should undergraduate pass the graduation verification",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.undergraduate).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.undergraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.undergraduate).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.undergraduate.address,2);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.undergraduate.address,1);
            await edutemplate.connect(accounts.teacher4).reviewThesis(accounts.undergraduate.address,1);
            await edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.undergraduate.address);
            const status = (await edutemplate.stuSets(accounts.undergraduate.address)).isGraduated;
            expect (status).to.be.equal(true);
        })

        it("Should be reverted because postgraduate's thesis hasn't reached the standard",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.postgraduate).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.postgraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.postgraduate).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.undergraduate.address,2);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.undergraduate.address,3);
            await edutemplate.connect(accounts.teacher4).reviewThesis(accounts.undergraduate.address,1);
            await edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.postgraduate.address);
            const status = (await edutemplate.stuSets(accounts.undergraduate.address)).isGraduated;
            expect (status).to.be.equal(false);
        })

        it("Should postgraduate pass the graduation verification",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.postgraduate).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.postgraduate).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.postgraduate).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.postgraduate.address,3);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.postgraduate.address,3);
            await edutemplate.connect(accounts.teacher4).reviewThesis(accounts.postgraduate.address,1);
            await edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.postgraduate.address);
            const status = (await edutemplate.stuSets(accounts.postgraduate.address)).isGraduated;
            expect (status).to.be.equal(true);
        })

        it("Should be reverted because phd's thesis hasn't reached the standard",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.phd).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.phd).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.phd).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.phd.address,3);
            await edutemplate.connect(accounts.teacher4).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.teacher5).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.teacher6).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.phd.address);
            const status = (await edutemplate.stuSets(accounts.phd.address)).isGraduated;
            expect (status).to.be.equal(false);
        })

        it("Should phd pass the graduation verification",async function () {
            const {edutemplate,accounts} = await loadFixture(deployAndRegisterMoreTeachers);
            await edutemplate.connect(accounts.phd).thesisInitialize(accounts.teacher1.address,"Title","Content");
            await edutemplate.connect(accounts.phd).modifyThesis("Modified Content");
            await edutemplate.connect(accounts.phd).thesisSubmit();
            await edutemplate.connect(accounts.teacher2).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.teacher3).reviewThesis(accounts.phd.address,3);
            await edutemplate.connect(accounts.teacher4).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.teacher5).reviewThesis(accounts.phd.address,3);
            await edutemplate.connect(accounts.teacher6).reviewThesis(accounts.phd.address,2);
            await edutemplate.connect(accounts.manangement).reviewGraduateQualification(accounts.phd.address);
            const status = (await edutemplate.stuSets(accounts.phd.address)).isGraduated;
            expect (status).to.be.equal(true);
        })
    })
});
