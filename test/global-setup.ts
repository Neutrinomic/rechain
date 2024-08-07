import { PocketIcServer } from '@hadronous/pic';


module.exports = async function (): Promise<void> {
  const pic = process.env['NO_MOTOKO_OUTPUT'] ? await PocketIcServer.start() : await PocketIcServer.start({showRuntimeLogs:false, showCanisterLogs:true });

  const url = pic.getUrl();

  process.env.PIC_URL = url;
  global.__PIC__ = pic;
};