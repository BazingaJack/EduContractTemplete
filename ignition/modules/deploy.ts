import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DeployModule = buildModule("DeployModule", (m) => {

  const edu = m.contract("EduTemplate", []);

  return { edu };
});

export default DeployModule;