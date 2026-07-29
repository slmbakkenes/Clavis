import {Assets} from 'assets'
import {observer} from 'mobx-react-lite'
import {Image, Linking, Text, TouchableOpacity, View} from 'react-native'
import packageInfo from '../../../package.json'

export const About = observer(() => {
  return (
    <View className="flex-1 justify-center items-center gap-2">
      <Image
        source={Assets.logoMinimal}
        style={{
          height: 200,
          width: 200,
        }}
      />
      <View className="gap-2 items-center">
        <Text className="text-3xl">Radix</Text>
        <Text className="darker-text text-xxs">{packageInfo.version}</Text>
        <Text className="darker-text text-xxs mt-2">
          Based on Sol by ospfranco (MIT)
        </Text>
        <View className="flex-row gap-2 mt-8">
          <TouchableOpacity
            className="bg-accent-strong p-2 rounded justify-center items-center w-48"
            onPress={() => {
              Linking.openURL('https://github.com/ospfranco/sol')
            }}>
            <Text className="text-white">Upstream Project</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  )
})
