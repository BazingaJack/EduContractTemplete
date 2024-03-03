// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./strings.sol";

//本合约模板的使用场景为教育领域，基于openzeppelin合约库中的AccessControlDefaultAdminRules标准合约模板进行开发
//使用AccessControlDefaultAdminRules标准合约模板的目的在于便捷地对使用场景中的角色进行定义、授权等一系列权限访问控制
//为了尽可能地简化开发流程和降低开发难度，本合约对部分实现细节做了一些简化，实际应用时可根据具体需求对数据结构进行一些调整
contract EduTemplate is AccessControlDefaultAdminRules{

    using ECDSA for bytes32;
    using strings for *;

    //以下是角色定义部分，每个角色以32字节作为标识，考虑做成常量，如果有新增角色定义，照着下方代码修改即可
    //管理员角色默认是合约的部署者，在构造函数中被初始化赋值，管理员角色可以给其他账户赋予角色和收回角色权限，包括临时权限
    bytes32 public constant STUDENT_ROLE = keccak256("STUDENT");//student
    bytes32 public constant TEACHER_ROLE = keccak256("TEACHER");//teacher
    bytes32 public constant MANAGEMENT_STUFF_ROLE = keccak256("MANAGEMENT_STUFF");//management stuff
    uint256 public nextRoleId;
    uint256 public nextCourseId;
    uint256 public nextScholarshipId;

    struct studentData {
        address addr;
        string name;
        uint256 age;
        uint256 enrollTime;
        string major;
        string stuType;//undergraduate,postgraduate,phd
        uint256 totalCredit;
        uint256 averageGrade;//todo
        uint256 scholarshipAmount;
        bool status;
    }

    struct teacherData {
        address addr;
        string name;
        uint256 age;
        string department;
        bool status;
    }

    struct managerData {
        address addr;
        string name;
        string department;
        bool status;
    }

    struct course {
        uint256 courseId;
        string name;
        uint256 credit;
        address teacherAddr;
    }

    struct scholarship {
        uint256 id;
        string name;
        uint256 amount;
        address[] applyer;//todo
        address winer;
        uint256 status;//0:initialize 1:gainer chosen,waiting for distribute 2:distributed
    }

    mapping(uint256 => bytes32) roles;
    mapping(address => mapping(uint256 => uint256)) tempRoles;
    mapping(address => studentData) stuSets;
    mapping(address => teacherData) thrSets;
    mapping(address => managerData) mgrSets;
    mapping(uint256 => course) courses;
    mapping(address => mapping(uint256 => uint256)) stuGrades;
    mapping(uint256 => mapping(address => bool)) courseStuSets;
    mapping(uint256 => scholarship) scholarships;
    mapping(uint256 => mapping(address => uint256)) applyList;

    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){
        roles[0] = STUDENT_ROLE;
        roles[1] = TEACHER_ROLE;
        roles[2] = MANAGEMENT_STUFF_ROLE;
        nextRoleId = 3;
        nextCourseId = 0;
        nextScholarshipId = 0;
    }

    //修饰器
    modifier roleValidCheck(uint256 _roleId) {
        require(_roleId >= 0 && _roleId < nextRoleId,"Error: Invalid role id.");
        _;
    }

    modifier checkStuType(string memory _type) {
        string memory s1 = "undergraduate";
        string memory s2 = "postgraduate";
        string memory s3 = "phd";
        bool res = false;
        res = res || _type.toSlice().equals(s1.toSlice());
        res = res || _type.toSlice().equals(s2.toSlice());
        res = res || _type.toSlice().equals(s3.toSlice());
        require(res == true,"Error: Invalid student type.");
        _;
    }

    //以下是和权限管理相关方法，暂不支持级联授权

    //checkRole函数用于检查给定的地址是否拥有某个角色权限
    function checkRole(address _checkAddr,uint256 _roleId) public view onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) returns(bool) {
        return hasRole(roles[_roleId], _checkAddr);
    }

    function checkTempRole(address _checkAddr,uint256 _roleId,uint256 _currentTimestamp)
    public view onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) returns (bool) {
        return tempRoles[_checkAddr][_roleId] >= _currentTimestamp;
    }

    //授予权限
    function adminGrantRole(address _toAddr,uint256 _roleId) public onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) {
        grantRole(roles[_roleId], _toAddr);
    }

    //回收权限
    function adminRevokeRole(address _fromAddr,uint256 _roleId) public onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId){
        require(checkRole(_fromAddr, _roleId) == true,"Error: This address owner hasn't this role");
        revokeRole(roles[_roleId], _fromAddr);
    }

    //临时授予/延长权限，到期自动收回
    function grantTempRole(address _toAddr,uint256 _roleId,uint256 _expireTime) 
    public onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) {
        require(checkRole(_toAddr, _roleId) == false,"Error: This address owner has already gained this role for long term");
        require(_expireTime > block.timestamp,"Error: Expire time should be larger than current timestamp.");
        uint256 expirationTime = tempRoles[_toAddr][_roleId];
        if(expirationTime < _expireTime) {
            tempRoles[_toAddr][_roleId] = _expireTime;
        }
    }

    // 学生相关方法 包括学籍注册/验证、毕业设计论文管理、毕业申请、奖学金申请、成绩管理等
    function stuRegister(address _stuAddr,string memory _name,uint256 _age,string memory _major,string memory _type)
    public onlyRole(DEFAULT_ADMIN_ROLE) checkStuType(_type){
        require(checkRole(_stuAddr, 0) == false,"Error: This address has already been registered as a student.");
        studentData memory d = studentData(_stuAddr,_name,_age,block.timestamp,_major,_type,0,0,0,true);
        stuSets[_stuAddr] = d;
        grantRole(roles[0], _stuAddr);
    }

    function stuVerify(address _stuAddr) public view returns(bool) {
        if(checkRole(_stuAddr, 0) == true){
            return stuSets[_stuAddr].status && stuSets[_stuAddr].enrollTime >= block.timestamp;
        }else{
            return false;
        }
    }

    function selectCourse(uint256 _courseId) public onlyRole(roles[0]){
        require(_courseId < nextCourseId,"Error: Invalid course id.");
        require(courseStuSets[_courseId][msg.sender] == false,"Error: This student has already selected this course.");
        courseStuSets[_courseId][msg.sender] = true;
    }

    function applyScholarship(uint256 _scholarshipId) public onlyRole(roles[0]) {
        require(_scholarshipId < nextScholarshipId,"Error: Invalid scholarship id.");
        require(applyList[_scholarshipId][msg.sender] == 0,"Error: You have applied for this scholarship.");
        scholarships[_scholarshipId].applyer.push(msg.sender);
        applyList[_scholarshipId][msg.sender] = stuSets[msg.sender].averageGrade;
    }

    // 教师相关方法 包括在岗信息注册/验证、学生成果管理、组成学位申请答辩临时委员会、表决答辩结果
    function thrRegister(address _thrAddr,string memory _name,uint256 _age,string memory _department)
    public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(checkRole(_thrAddr, 1) == false,"Error: This address has already been registered as a teacher.");
        teacherData memory d = teacherData(_thrAddr,_name,_age,_department,true);
        thrSets[_thrAddr] = d;
        grantRole(roles[1], _thrAddr);
    }

    function thrVerify(address _thrAddr) public view returns(bool) {
        return checkRole(_thrAddr,1);
    }
    
    function registerCourse(string memory _name,uint256 _credit) public onlyRole(roles[1]) {
        course memory c = course(nextCourseId,_name,_credit,msg.sender);
        nextCourseId++;
        courses[c.courseId] = c;
    }

    function recordScores(address _stuAddr,uint256 _courseId,uint256 _grade) public onlyRole(roles[1]) {
        require(stuVerify(_stuAddr) == true,"Error: This address owner isn't a student.");
        require(_courseId < nextCourseId,"Error: Invalid course id.");
        require(courses[_courseId].teacherAddr == msg.sender,"Error: You aren't the manager of this course.");
        require(courseStuSets[_courseId][_stuAddr] == true,"Error: This student hasn't selected this course.");
        if(_grade < 60) {
            stuSets[_stuAddr].status = false;
        }
        stuSets[_stuAddr].averageGrade = (stuSets[_stuAddr].averageGrade * stuSets[_stuAddr].totalCredit + courses[_courseId].credit * _grade) / (stuSets[_stuAddr].totalCredit + courses[_courseId].credit);
        stuSets[_stuAddr].totalCredit += courses[_courseId].credit;
        stuGrades[_stuAddr][_courseId] = _grade;
    }

    // 行政管理人员相关方法 添加奖学金信息 审核奖学金申请、材料存证/公证、数字毕业证书发放与验证
    function mgrRegister(address _mgrAddr,string memory _name,string memory _department)
    public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(checkRole(_mgrAddr, 2) == false,"Error: This address has already been registered as a manager.");
        managerData memory d = managerData(_mgrAddr,_name,_department,true);
        mgrSets[_mgrAddr] = d;
        grantRole(roles[0], _mgrAddr);
    }

    function addScholarship(string memory _name,uint256 _amount) public onlyRole(roles[2]) {
        address[] memory applyer;
        scholarship memory s = scholarship(nextScholarshipId,_name,_amount,applyer,address(0),0);
        scholarships[nextScholarshipId] = s;
        nextScholarshipId++;
    }

    function chooseCandidate(uint256 _scholarshipId) public onlyRole(roles[2]) {
        require(_scholarshipId < nextScholarshipId,"Error: Invalid scholarship id.");
        require(scholarships[_scholarshipId].status == 0,"Error: This scholarship has already been processed.");
        require(scholarships[_scholarshipId].applyer.length > 0,"Error: This scholarship hasn't applyer yet.");
        address winer = scholarships[_scholarshipId].applyer[0];
        uint256 maxGrade = stuSets[winer].averageGrade;
        if(scholarships[_scholarshipId].applyer.length >= 2){
            for(uint256 i = 1;i < scholarships[_scholarshipId].applyer.length;i++){//todo
                address s = scholarships[_scholarshipId].applyer[i];
                if(maxGrade < stuSets[s].averageGrade){
                    winer = s;
                    maxGrade = stuSets[s].averageGrade;
                }
            }
        }
        scholarships[_scholarshipId].winer = winer;
        scholarships[_scholarshipId].status = 1;
    }

    function distributeScholarship(uint256 _scholarshipId) public onlyRole(roles[2]){
        require(_scholarshipId < nextScholarshipId,"Error: Invalid scholarship id.");
        require(scholarships[_scholarshipId].status == 1,"Error: This scholarship hasn't been processed.");
        address winer = scholarships[_scholarshipId].winer;
        stuSets[winer].scholarshipAmount += scholarships[_scholarshipId].amount;
        scholarships[_scholarshipId].status = 2;
    }





    

}