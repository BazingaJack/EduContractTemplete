// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

//本合约模板的使用场景为教育领域，基于openzeppelin合约库中的AccessControlDefaultAdminRules标准合约模板进行开发
//使用AccessControlDefaultAdminRules标准合约模板的目的在于便捷地对使用场景中的角色进行定义、授权等一系列权限访问控制
//为了尽可能地简化开发流程和降低开发难度，本合约对部分实现细节做了一些简化，实际应用时可根据具体需求对数据结构进行一些调整
contract EduTemplate is AccessControlDefaultAdminRules{
    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){

    }
}