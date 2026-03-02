const { extract } = require('./scripts/extract.js');

const url = 'https://mp.weixin.qq.com/s/-vXqPXxwbPsw9MI78lfz7Q';

extract(url).then(result => {
  console.log('Extraction Result:', JSON.stringify(result, null, 2));
  console.log('\nStatus:', result.done ? 'Success' : 'Failed');
  if (!result.done) {
    console.log('Error Code:', result.code);
    console.log('Error Message:', result.msg);
  } else {
    console.log('Title:', result.data.msg_title);
    console.log('Author:', result.data.msg_author);
    console.log('Publish Time:', result.data.msg_publish_time_str);
    console.log('Account:', result.data.account_name);
  }
}).catch(err => {
  console.error('Script Error:', err);
});