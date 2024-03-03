// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//本合约模板的使用场景为教育领域，基于openzeppelin合约库中的AccessControlDefaultAdminRules标准合约模板进行开发
//使用AccessControlDefaultAdminRules标准合约模板的目的在于便捷地对使用场景中的角色进行定义、授权等一系列权限访问控制
//为了尽可能地简化开发流程和降低开发难度，本合约对部分实现细节做了一些简化，实际应用时可根据具体需求对数据结构进行一些调整
contract EduTemplate is AccessControlDefaultAdminRules{

    //以下是角色定义部分，每个角色以32字节作为标识，考虑做成常量，如果有新增角色定义，照着下方代码修改即可
    //管理员角色默认是合约的部署者，在构造函数中被初始化赋值，管理员角色可以给其他账户赋予角色和收回角色权限，包括临时权限
    bytes32 public constant STUDENT_ROLE = keccak256("STUDENT");//student
    bytes32 public constant TEACHER_ROLE = keccak256("TEACHER");//teacher
    bytes32 public constant MANAGEMENT_STUFF_ROLE = keccak256("MANAGEMENT_STUFF");//management stuff
    address public degreeManagementDepartment;
    uint256 public nextRoleId;
    uint256 public nextCourseId;
    uint256 public nextScholarshipId;
    uint256 public nextThesisId;

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
        uint256 thesisId;
        bool isGraduated;
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

    struct thesis{
        uint256 id;
        address stuAddr;
        address thrAddr;
        string title;
        string content;
        uint256 status;//0:initialize 1:submitted,waiting for reviews 2:reviewed
    }

    struct reviewRecord{
        address thrAddr;
        uint256 thesisId;
        uint256 result;//0:unqualified 1:qualified 2:good 3:excellent
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
    mapping(uint256 => thesis) thesisSets;
    mapping(uint256 => reviewRecord[]) thesisResults;
    mapping(address => bytes32) certificates;

    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){
        roles[0] = STUDENT_ROLE;
        roles[1] = TEACHER_ROLE;
        roles[2] = MANAGEMENT_STUFF_ROLE;
        nextRoleId = 3;
        nextCourseId = 0;
        nextScholarshipId = 0;
        nextThesisId = 0;
        degreeManagementDepartment = msg.sender;
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
        res = Strings.equal(_type,s1) || Strings.equal(_type,s2) || Strings.equal(_type,s3);
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

    // 学生相关方法 包括学籍注册/验证、毕业设计论文管理、奖学金申请、成绩管理等
    function stuRegister(address _stuAddr,string memory _name,uint256 _age,string memory _major,string memory _type)
    public onlyRole(DEFAULT_ADMIN_ROLE) checkStuType(_type){
        require(checkRole(_stuAddr, 0) == false,"Error: This address has already been registered as a student.");
        studentData memory d = studentData(_stuAddr,_name,_age,block.timestamp,_major,_type,0,0,0,0,false,true);
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

    function thesisInitialize(address _thrAddr,string memory _title,string memory _content) public onlyRole(roles[0]) {
        require(checkRole(_thrAddr, 1) == true,"Error: This teacher doesn't exist.");
        thesis memory t = thesis(nextThesisId,msg.sender,_thrAddr,_title,_content,0);
        thesisSets[nextThesisId] = t;
        nextThesisId++;
    }

    function modifyThesis(string memory _content) public onlyRole(roles[0]) {
        require(stuSets[msg.sender].thesisId > 0,"Error: Could not find corresponding thesis.");
        thesisSets[stuSets[msg.sender].thesisId].content = _content;
    }

    function thesisSubmit() public onlyRole(roles[0]) {
        require(stuSets[msg.sender].thesisId > 0,"Error: Could not find corresponding thesis.");
        require(thesisSets[stuSets[msg.sender].thesisId].status == 0,"Error: Invalid status.");
        thesisSets[stuSets[msg.sender].thesisId].status = 1;
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

    function reviewThesis(address _stuAddr,uint256 _reviewResult) public onlyRole(roles[1]) {
        require(stuVerify(_stuAddr) == true,"Error: This address owner isn't a student.");
        require(stuSets[_stuAddr].thesisId > 0,"Error: Could not find corresponding thesis.");
        require(thesisSets[stuSets[_stuAddr].thesisId].status == 1,"Error: Invalid status.");
        require(thesisSets[stuSets[_stuAddr].thesisId].thrAddr == msg.sender,"Error: You can't review your student's thesis.");
        thesis memory t = thesisSets[stuSets[_stuAddr].thesisId];
        reviewRecord memory r = reviewRecord(msg.sender,t.id,_reviewResult);
        thesisResults[t.id].push(r);
        string memory s = "phd";
        if(Strings.equal(stuSets[_stuAddr].stuType, s)){//人数不少于5人
            if(thesisResults[t.id].length == 5) thesisSets[stuSets[_stuAddr].thesisId].status = 2;
        }else{//人数不少于3人
            if(thesisResults[t.id].length == 3) thesisSets[stuSets[_stuAddr].thesisId].status = 2;
        }
    }

    // 行政管理人员相关方法 添加奖学金信息 审核奖学金申请、审核毕业资格、材料存证/公证、数字毕业证书发放与验证
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

    function reviewGraduateQualification(address _stuAddr) public onlyRole(roles[2]) returns(bool) {
        require(stuVerify(_stuAddr) == true,"Error: This address owner isn't a student.");
        require(stuSets[_stuAddr].status == true,"Error: Invalid status.");
        require(thesisSets[stuSets[_stuAddr].thesisId].status == 2,"Error: Your thesis hasn't been reviewed yet.");
        reviewRecord[] memory records = thesisResults[stuSets[_stuAddr].thesisId];
        string memory s1 = "undergraduate";
        string memory s2 = "postgraduate";
        bool res = true;
        if(Strings.equal(stuSets[_stuAddr].stuType, s1)){//均为及格以上即可
            for(uint256 i = 0;i < records.length;i++){
                if(records[i].result == 0){
                    res = false;
                    break;
                }
            }
        }else if (Strings.equal(stuSets[_stuAddr].stuType, s2)){//及格以上，并且有C的情况下只有1C2A能通过
            uint256 score = 0;
            for(uint256 i = 0;i < records.length;i++){
                if(records[i].result == 0){
                    res = false;
                    break;
                }else score += records[i].result;
            }
            if(score < 7) res = false;
        }else{//
            uint256 score = 0;
            for(uint256 i = 0;i < records.length;i++){//至少2A3B
                if(records[i].result == 0 || records[i].result == 1){
                    res = false;
                    break;
                }else score += records[i].result;
            }
            if(score < 12) res = false;
        }
        if(res){
            stuSets[_stuAddr].isGraduated = true;
        }
        return res;
    }

    function signCertificate(address _stuAddr,bytes memory _signature) external {
        require(msg.sender == degreeManagementDepartment, "Error: Only degree management department can sign certificates");
        require(stuVerify(_stuAddr) == true,"Error: This address owner isn't a student.");
        require(stuSets[_stuAddr].status == true && stuSets[_stuAddr].isGraduated == true,"Error: This student hasn't graduated yet.");
        bytes32 message = keccak256(abi.encodePacked(stuSets[_stuAddr].name,Strings.toString(block.timestamp)));//todo
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(message);
        require(ECDSA.recover(digest, _signature) == degreeManagementDepartment,"Error: Invalid signature.");
        certificates[_stuAddr] = digest;
    }

    function verifyCertificate(address _stuAddr,bytes32 _certHash,bytes memory _signature) external view returns(bool) {
        require(msg.sender == degreeManagementDepartment, "Error: Only degree management department can sign certificates");
        require(stuVerify(_stuAddr) == true,"Error: This address owner isn't a student.");
        require(certificates[_stuAddr] == _certHash,"Error: Incorrect certificate hash.");
        return ECDSA.recover(_certHash, _signature) == degreeManagementDepartment;
    }
}