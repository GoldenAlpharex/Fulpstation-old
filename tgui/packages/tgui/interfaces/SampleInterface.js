import { useBackend } from '../backend';
import { Button, LabeledList, Section } from '../components';
import { Window } from '../layouts';

export const SampleInterface = (props, context) => {
    const { act, data } = useBackend(context);
    // Extract `health` and `color` variables from the `data` object.
    const {
        health,
        color,
    } = data;
    return (
        <Window resizable>
            <Window.Content scrollable>
                <Section title="Health status">
                    <LabeledList>
                        <LabeledList.Item label="Health">
                            {health}
                        </LabeledList.Item>
                        <LabeledList.Item label="Color">
                            {color}
                        </LabeledList.Item>
                        <LabeledList.Item label="Button">
                            <Button
                                content="Change the color to #ffffff"
                                onClick={() => act('change_color', {
                                    color: "#ff00ff"
                                })} />
                        </LabeledList.Item>
                    </LabeledList>
                </Section>
            </Window.Content>
        </Window>
    );
};