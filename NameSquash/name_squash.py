def squash_strings(n1, n2):
    name_list = []
    for i in range(0, len(n1)):
        for j in range(0, len(n2)):
            name_list.append(n1[:i+1] + n2[j:].lower())
    return name_list

name_list = squash_strings('Cory', 'Alexxa')
name_list.extend(squash_strings('Alexxa','Cory'))

for name in name_list:
    print(name)
