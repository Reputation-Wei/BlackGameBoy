import json

def process_opcodes():
    with open('opcode.json', 'r') as f:
        data = json.load(f)
    
    opcodes = data['unprefixed']
    result = []
    
    for opcode, info in opcodes.items():
        mnemonic = info['mnemonic']
        operands = [op['name'] for op in info['operands']]
        
        if operands:
            formatted = f"{mnemonic}_{'_'.join(operands)}"
        else:
            formatted = mnemonic
            
        # 将0x格式转换为8'h格式
        hex_value = opcode.replace('0x', '')
        result.append(f"{formatted} = 8'h{hex_value}")
    
    return result

if __name__ == "__main__":
    results = process_opcodes()
    # 将结果写入文件
    with open('opcodes.txt', 'w') as f:
        for line in results:
            f.write(line + '\n')
            print(line)  # 同时在控制台显示 