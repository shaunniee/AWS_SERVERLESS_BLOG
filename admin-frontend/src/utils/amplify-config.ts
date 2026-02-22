import { Amplify } from 'aws-amplify';
import { AUTH_CONFIGURED, COGNITO_CLIENT_ID, COGNITO_USER_POOL_ID } from '@/utils/constants';

if (AUTH_CONFIGURED) {
  Amplify.configure({
    Auth: {
      Cognito: {
        userPoolId: COGNITO_USER_POOL_ID,
        userPoolClientId: COGNITO_CLIENT_ID,
        loginWith: {
          username: true,
        },
      },
    },
  });
} else {
  console.warn('Cognito credentials not configured. Update frontend/.env.local to enable authentication.');
}

export default Amplify;
